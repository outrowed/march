#!/usr/bin/env python3
"""
Auto-create root/home partitions for march on an empty disk.

Usage:
    sudo python3 auto-partition.py /dev/sdX [root_percent]

Notes:
- Requires an empty disk (no existing partitions). Will create a GPT and two ext4 partitions.
- Labels and filesystem types are read from config.sh (IROOT_PARTITION_LABEL/IHOME_PARTITION_LABEL and *_FSTYPE).
- root_percent defaults to 60; the remainder goes to home.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import stat
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.sh"


def run(cmd: List[str]) -> None:
    print(">", " ".join(cmd))
    proc = subprocess.run(cmd, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")


def load_config() -> Dict[str, str]:
    names = [
        "IROOT_PARTITION_LABEL",
        "IHOME_PARTITION_LABEL",
        "IROOT_PARTITION_FSTYPE",
        "IHOME_PARTITION_FSTYPE",
    ]
    name_str = " ".join(shlex.quote(v) for v in names)
    cmd = ["bash", "-lc", f"source config.sh; for v in {name_str}; do declare -p \"$v\" 2>/dev/null; done"]
    proc = subprocess.run(cmd, cwd=BASE_DIR, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr or "Failed to parse config.sh")
    vals: Dict[str, str] = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line.startswith("declare"):
            continue
        m = re.match(r"declare\s+-[a-zA-Z]+\s+([A-Za-z0-9_]+)=\"?(.*?)\"?$", line)
        if m:
            vals[m.group(1)] = bytes(m.group(2), "utf-8").decode("unicode_escape")
    for req in names:
        if req not in vals:
            raise RuntimeError(f"{req} missing in config.sh")
    return vals


def ensure_block_device(path: Path) -> None:
    st = path.stat()
    if not stat.S_ISBLK(st.st_mode):
        raise RuntimeError(f"{path} is not a block device")


def lsblk_info(disk: str) -> Tuple[List[Dict], List[Dict]]:
    out = subprocess.check_output(
        [
            "lsblk",
            "--json",
            "--bytes",
            "-o",
            "NAME,PATH,TYPE,SIZE,START,PKNAME",
        ],
        text=True,
    )
    data = json.loads(out)
    flat: List[Dict] = []

    def walk(node: Dict, parent_disk: str | None):
        current_disk = parent_disk or (f"/dev/{node['name']}" if node["type"] == "disk" else parent_disk)
        flat.append(
            {
                "name": node.get("name"),
                "path": node.get("path"),
                "type": node.get("type"),
                "size": int(node.get("size") or 0),
                "start": int(node.get("start") or 0),
                "pkname": node.get("pkname"),
                "disk": current_disk,
            }
        )
        for child in node.get("children", []):
            walk(child, current_disk)

    for top in data.get("blockdevices", []):
        walk(top, None)

    disk_parts = [p for p in flat if p["disk"] == disk and p["type"] == "part"]
    disks = [p for p in flat if p["type"] == "disk"]
    return disk_parts, disks


def derive_partition_paths(disk: str) -> List[str]:
    parts, _ = lsblk_info(disk)
    return [p["path"] for p in parts]


def confirm(prompt: str) -> bool:
    ans = input(f"{prompt} [y/N]: ").strip().lower()
    return ans == "y"


def main() -> None:
    if os.geteuid() != 0:
        print("Run as root.")
        sys.exit(1)
    if len(sys.argv) < 2:
        print("Usage: sudo python3 auto-partition.py /dev/sdX [root_percent]")
        sys.exit(1)
    disk = sys.argv[1]
    root_percent = 60
    if len(sys.argv) >= 3:
        try:
            root_percent = int(sys.argv[2])
        except ValueError:
            print("root_percent must be an integer (e.g., 60).")
            sys.exit(1)
    if root_percent <= 0 or root_percent >= 100:
        print("root_percent must be between 1 and 99.")
        sys.exit(1)

    disk_path = Path(disk)
    try:
        ensure_block_device(disk_path)
    except Exception as exc:  # noqa: BLE001
        print(exc)
        sys.exit(1)

    parts, disks = lsblk_info(disk)
    if any(p["type"] == "part" for p in parts):
        print(f"{disk} already has partitions; aborting.")
        sys.exit(1)

    cfg = load_config()
    if cfg["IROOT_PARTITION_FSTYPE"] != "ext4" or cfg["IHOME_PARTITION_FSTYPE"] != "ext4":
        print("This script only handles ext4 root/home.")
        sys.exit(1)

    print(
        f"""
Target disk: {disk}
Root label: {cfg['IROOT_PARTITION_LABEL']} ({cfg['IROOT_PARTITION_FSTYPE']})
Home label: {cfg['IHOME_PARTITION_LABEL']} ({cfg['IHOME_PARTITION_FSTYPE']})
Root percent: {root_percent}%, Home percent: {100 - root_percent}%
"""
    )
    if not confirm("This will wipe the disk and create two partitions. Continue?"):
        sys.exit(1)

    try:
        run(["wipefs", "-af", disk])
        run(["parted", "-s", disk, "mklabel", "gpt"])
        run(["parted", "-s", disk, "mkpart", "primary", "ext4", "1MiB", f"{root_percent}%"])
        run(["parted", "-s", disk, "name", "1", cfg["IROOT_PARTITION_LABEL"]])
        run(["parted", "-s", disk, "mkpart", "primary", "ext4", f"{root_percent}%", "100%"])
        run(["parted", "-s", disk, "name", "2", cfg["IHOME_PARTITION_LABEL"]])
        run(["partprobe", disk])
        paths = derive_partition_paths(disk)
        if len(paths) < 2:
            raise RuntimeError("Could not find new partitions after creation.")
        root_part = sorted(paths)[0]
        home_part = sorted(paths)[1]
        run(["mkfs.ext4", "-F", "-L", cfg["IROOT_PARTITION_LABEL"], root_part])
        run(["mkfs.ext4", "-F", "-L", cfg["IHOME_PARTITION_LABEL"], home_part])
        print("Partitions created:")
        run(["lsblk", "-o", "NAME,PATH,PARTLABEL,FSTYPE,SIZE", disk])
    except Exception as exc:  # noqa: BLE001
        print("Error:", exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
