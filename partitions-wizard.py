#!/usr/bin/env python3
"""
Text UI partition planner for the March installer.

Goals:
- Run on a plain Arch ISO (no desktop). Uses only Python stdlib plus lsblk/parted/sgdisk.
- Let you stage create/delete/move/resize/label actions, then apply them in order.
- Assign root/home/EFI/swap roles and write matching values into config.sh.

Usage:
    python3 partition_planner_gui.py

Notes:
- Run as root; parted/sgdisk require it.
- Sizes accept suffixes like: 1KB, 100K, 10M, 10MB, 10MiB, 10G, 10GB, 10GiB.
- Root/home mounting in install.sh relies on PARTLABEL, so set labels before saving config.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from shutil import get_terminal_size
from typing import Dict, List, Optional

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.sh"


# --- Helpers -----------------------------------------------------------------
def run(cmd: List[str]) -> None:
    """Run a command and raise with stderr if it fails."""
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"Command failed: {' '.join(cmd)}")


def load_lsblk() -> List[Dict]:
    """Return flattened lsblk rows for disks and partitions."""
    out = subprocess.check_output(
        [
            "lsblk",
            "--bytes",
            "--json",
            "-o",
            "NAME,PATH,SIZE,START,TYPE,FSTYPE,PARTLABEL,LABEL,MOUNTPOINT,PKNAME",
        ],
        text=True,
    )
    data = json.loads(out)
    flat: List[Dict] = []

    def walk(node: Dict, parent_disk: Optional[str]):
        current_disk = parent_disk or (f"/dev/{node['name']}" if node["type"] == "disk" else parent_disk)
        flat.append(
            {
                "name": node.get("name"),
                "path": node.get("path"),
                "size": int(node.get("size") or 0),
                "start": int(node.get("start") or 0),
                "type": node.get("type"),
                "fstype": node.get("fstype") or "",
                "partlabel": node.get("partlabel") or "",
                "label": node.get("label") or "",
                "mountpoint": node.get("mountpoint") or "",
                "pkname": node.get("pkname"),
                "disk": current_disk,
            }
        )
        for child in node.get("children", []):
            walk(child, current_disk)

    for top in data.get("blockdevices", []):
        walk(top, None)

    return flat


def bytes_to_mib(value: int) -> float:
    return round(value / (1024 * 1024), 3)


SIZE_RE = re.compile(r"(?i)^\s*(\d+(?:\.\d+)?)([kmgt]?i?b?)?\s*$")


def parse_size_to_mib(text: str) -> float:
    """
    Parse sizes like 1KB, 100K, 10M, 10MB, 10MiB, 10G, 10GB, 10GiB into MiB.
    Default unit is MiB if omitted.
    """
    m = SIZE_RE.match(text or "")
    if not m:
        raise ValueError(f"Invalid size: {text!r}")
    value = float(m.group(1))
    suffix = (m.group(2) or "").lower()
    if suffix in ("", "m", "mb", "mib"):
        factor = 1.0
    elif suffix in ("k", "kb"):
        factor = 1_000 / (1024 * 1024)
    elif suffix in ("ki", "kib"):
        factor = 1 / 1024
    elif suffix in ("g", "gb"):
        factor = 1_000_000_000 / (1024 * 1024)
    elif suffix in ("gi", "gib"):
        factor = 1024
    else:
        raise ValueError(f"Unknown size suffix: {suffix}")
    return round(value * factor, 3)


def prompt(msg: str, default: Optional[str] = None) -> str:
    suffix = f" [{default}]" if default is not None else ""
    ans = input(f"{msg}{suffix}: ").strip()
    if not ans and default is not None:
        return default
    return ans


def part_number_from_name(name: Optional[str]) -> Optional[str]:
    if not name:
        return None
    m = re.search(r"(\d+)$", name)
    return m.group(1) if m else None


# --- Planner -----------------------------------------------------------------
class Planner:
    def __init__(self) -> None:
        self.partitions: List[Dict] = []
        self.part_index: Dict[str, Dict] = {}
        self.disks: List[str] = []
        self.disk: Optional[str] = None
        self.plan: List[Dict] = []
        self.assignments: Dict[str, Optional[Dict[str, str]]] = {
            "root": None,
            "home": None,
            "efi": None,
            "swap": None,
        }
        self.swap_mode = "zram+swapfile"
        self.refresh()

    def refresh(self) -> None:
        self.partitions = load_lsblk()
        self.part_index = {p["path"]: p for p in self.partitions}
        self.disks = sorted({p["disk"] for p in self.partitions if p["type"] == "disk"})
        if self.disks and self.disk not in self.disks:
            self.disk = self.disks[0]

    # --- Display helpers ---
    @staticmethod
    def _column_widths(term_cols: int) -> Dict[str, int]:
        """Compute column widths that fit smaller terminals."""
        widths = {
            "idx": 3,
            "path": 18,
            "num": 4,
            "size": 10,
            "fstype": 8,
            "partlabel": 20,
            "label": 15,
            "mount": 12,
        }
        min_widths = {
            "path": 10,
            "partlabel": 8,
            "label": 6,
            "mount": 6,
        }
        total = sum(widths.values()) + 7  # spaces/separators slack
        if term_cols >= total:
            return widths

        # Reduce larger text columns until we fit or hit minimums
        order = ["path", "partlabel", "label", "mount"]
        idx = 0
        while total > term_cols and idx < len(order):
            col = order[idx]
            if widths[col] > min_widths[col]:
                widths[col] -= 1
                total -= 1
            else:
                idx += 1
        return widths

    @staticmethod
    def _truncate(text: str, width: int) -> str:
        if len(text) <= width:
            return text
        if width <= 1:
            return text[:width]
        return text[: width - 1] + "…"

    def list_partitions(self) -> List[Dict]:
        parts = [p for p in self.partitions if p["disk"] == self.disk and p["type"] == "part"]
        print(f"\nCurrent disk: {self.disk or '(none)'}")
        if not parts:
            print("No partitions.")
            return parts
        term_cols = get_terminal_size(fallback=(80, 20)).columns
        w = self._column_widths(term_cols)
        header = (
            f"{'#':<{w['idx']}} "
            f"{'Path':<{w['path']}} "
            f"{'Num':<{w['num']}} "
            f"{'Size(MiB)':<{w['size']}} "
            f"{'FSType':<{w['fstype']}} "
            f"{'PARTLABEL':<{w['partlabel']}} "
            f"{'LABEL':<{w['label']}} "
            f"{'Mount':<{w['mount']}}"
        )
        print(header)
        print("-" * len(header))
        for idx, p in enumerate(parts):
            partnum = part_number_from_name(p["name"]) or "-"
            print(
                f"{idx:<{w['idx']}} "
                f"{self._truncate(p['path'], w['path']):<{w['path']}} "
                f"{partnum:<{w['num']}} "
                f"{bytes_to_mib(p['size']):<{w['size']}} "
                f"{self._truncate(p['fstype'], w['fstype']):<{w['fstype']}} "
                f"{self._truncate(p['partlabel'], w['partlabel']):<{w['partlabel']}} "
                f"{self._truncate(p['label'], w['label']):<{w['label']}} "
                f"{self._truncate(p['mountpoint'], w['mount']):<{w['mount']}}"
            )
        return parts

    def show_plan(self) -> None:
        if not self.plan:
            print("\nPlan is empty.")
            return
        print("\nPlanned actions (in order):")
        for idx, act in enumerate(self.plan):
            print(f"  {idx}) {act['summary']}")

    def show_assignments(self) -> None:
        print("\nAssignments (to be written to config.sh):")
        for role in ("root", "home", "efi", "swap"):
            val = self.assignments.get(role)
            if not val:
                print(f"  {role:<5}: (unset)")
            else:
                extra = f" label={val.get('label','')}" if val.get("label") else ""
                print(f"  {role:<5}: {val.get('path','')} {extra}")
        print(f"  swap mode: {self.swap_mode}")

    # --- Actions ---
    def choose_disk(self) -> None:
        print("\nDisks:")
        for idx, d in enumerate(self.disks):
            print(f"  {idx}) {d}")
        choice = prompt("Select disk number", default="0")
        try:
            idx = int(choice)
            self.disk = self.disks[idx]
        except Exception:
            print("Invalid disk choice.")

    def add_create(self) -> None:
        if not self.disk:
            print("Select a disk first.")
            return
        start = prompt("Start offset (e.g., 1MiB, 10G)", default="1MiB")
        size = prompt("Size", default="1024MiB")
        fs = prompt("Filesystem type hint", default="ext4")
        try:
            start_mib = parse_size_to_mib(start)
            size_mib = parse_size_to_mib(size)
        except ValueError as exc:
            print(exc)
            return
        end_mib = round(start_mib + size_mib, 3)
        summary = f"{self.disk}: create primary {fs} start {start_mib}MiB size {size_mib}MiB"
        self.plan.append(
            {"type": "create", "disk": self.disk, "start": start_mib, "end": end_mib, "fs": fs, "summary": summary}
        )
        print("Added:", summary)

    def add_delete(self) -> None:
        parts = self.list_partitions()
        if not parts:
            return
        choice = prompt("Partition index to delete")
        try:
            part = parts[int(choice)]
        except Exception:
            print("Invalid selection.")
            return
        partnum = part_number_from_name(part["name"])
        if not partnum:
            print("Could not determine partition number.")
            return
        summary = f"{self.disk}: delete partition {partnum} ({part['path']})"
        self.plan.append({"type": "delete", "disk": self.disk, "part": partnum, "summary": summary})
        print("Added:", summary)

    def add_resize(self) -> None:
        parts = self.list_partitions()
        if not parts:
            return
        choice = prompt("Partition index to resize")
        try:
            part = parts[int(choice)]
        except Exception:
            print("Invalid selection.")
            return
        size = prompt("New size", default="1024MiB")
        try:
            size_mib = parse_size_to_mib(size)
        except ValueError as exc:
            print(exc)
            return
        start_mib = bytes_to_mib(part["start"])
        end_mib = round(start_mib + size_mib, 3)
        partnum = part_number_from_name(part["name"])
        summary = f"{self.disk}: resize {partnum} to {size_mib}MiB (end {end_mib}MiB)"
        self.plan.append({"type": "resize", "disk": self.disk, "part": partnum, "end": end_mib, "summary": summary})
        print("Added:", summary)

    def add_move(self) -> None:
        parts = self.list_partitions()
        if not parts:
            return
        choice = prompt("Partition index to move")
        try:
            part = parts[int(choice)]
        except Exception:
            print("Invalid selection.")
            return
        start = prompt("New start", default="1MiB")
        try:
            new_start_mib = parse_size_to_mib(start)
        except ValueError as exc:
            print(exc)
            return
        size_mib = bytes_to_mib(part["size"])
        end_mib = round(new_start_mib + size_mib, 3)
        partnum = part_number_from_name(part["name"])
        summary = f"{self.disk}: move {partnum} to start {new_start_mib}MiB (end {end_mib}MiB)"
        self.plan.append(
            {"type": "move", "disk": self.disk, "part": partnum, "start": new_start_mib, "end": end_mib, "summary": summary}
        )
        print("Added:", summary)

    def add_move_relative(self) -> None:
        parts = self.list_partitions()
        if len(parts) < 2:
            print("Need at least two partitions to move relative to another.")
            return
        try:
            moving = parts[int(prompt("Partition index to move"))]
            target = parts[int(prompt("Target partition index"))]
        except Exception:
            print("Invalid selection.")
            return
        position = prompt("Place (before|after)", default="after").lower()
        if position not in ("before", "after"):
            print("Choice must be 'before' or 'after'.")
            return
        size_mib = bytes_to_mib(moving["size"])
        target_start = bytes_to_mib(target["start"])
        target_size = bytes_to_mib(target["size"])
        if position == "before":
            new_start_mib = round(target_start - size_mib, 3)
            if new_start_mib < 0:
                print("Computed start is negative; aborting.")
                return
        else:
            new_start_mib = round(target_start + target_size, 3)
        end_mib = round(new_start_mib + size_mib, 3)
        partnum = part_number_from_name(moving["name"])
        summary = f"{self.disk}: move {partnum} {position} {part_number_from_name(target['name'])} -> start {new_start_mib}MiB"
        self.plan.append(
            {"type": "move", "disk": self.disk, "part": partnum, "start": new_start_mib, "end": end_mib, "summary": summary}
        )
        print("Added:", summary)

    def add_label(self) -> None:
        parts = self.list_partitions()
        if not parts:
            return
        choice = prompt("Partition index to label")
        try:
            part = parts[int(choice)]
        except Exception:
            print("Invalid selection.")
            return
        new_label = prompt("New PARTLABEL")
        if not new_label:
            print("Label cannot be empty.")
            return
        partnum = part_number_from_name(part["name"])
        summary = f"{self.disk}: set label {partnum} -> {new_label}"
        self.plan.append({"type": "label", "disk": self.disk, "part": partnum, "label": new_label, "summary": summary})
        print("Added:", summary)

    # --- Apply ---
    def apply_plan(self) -> None:
        if not self.plan:
            print("Plan is empty.")
            return
        confirm = prompt("Apply plan now? (yes/no)", default="no").lower()
        if confirm not in ("y", "yes"):
            print("Aborted.")
            return
        for act in list(self.plan):
            try:
                self._execute_action(act)
                print("Applied:", act["summary"])
            except Exception as exc:  # noqa: BLE001
                print(f"Failed: {act['summary']}\n  -> {exc}")
                return
        print("Plan applied successfully.")
        self.plan.clear()
        self.refresh()

    def _execute_action(self, action: Dict) -> None:
        disk = action["disk"]
        if action["type"] == "create":
            run(
                [
                    "parted",
                    "-s",
                    disk,
                    "unit",
                    "MiB",
                    "mkpart",
                    "primary",
                    action["fs"],
                    f"{action['start']}",
                    f"{action['end']}",
                ]
            )
        elif action["type"] == "delete":
            run(["parted", "-s", disk, "rm", str(action["part"])])
        elif action["type"] == "resize":
            run(["parted", "-s", disk, "unit", "MiB", "resizepart", str(action["part"]), f"{action['end']}"])
        elif action["type"] == "move":
            run(
                [
                    "parted",
                    "-s",
                    disk,
                    "unit",
                    "MiB",
                    "move",
                    str(action["part"]),
                    f"{action['start']}",
                    f"{action['end']}",
                ]
            )
        elif action["type"] == "label":
            run(["sgdisk", f"--change-name={action['part']}:{action['label']}", disk])
        else:
            raise ValueError(f"Unknown action type: {action['type']}")

    # --- Assignments / config ---
    def assign_role(self) -> None:
        parts = self.list_partitions()
        if not parts:
            return
        role = prompt("Role to set (root/home/efi/swap)").lower()
        if role not in ("root", "home", "efi", "swap"):
            print("Invalid role.")
            return
        choice = prompt("Partition index to use for this role")
        try:
            part = parts[int(choice)]
        except Exception:
            print("Invalid selection.")
            return
        partnum = part_number_from_name(part["name"])
        label = part.get("partlabel") or part.get("label") or ""
        if role in ("root", "home") and not label:
            print("Root/home require PARTLABEL. Add a label first.")
            return
        self.assignments[role] = {"path": part["path"], "label": label, "partnum": partnum}
        print(f"Assigned {role} -> {part['path']} (label: {label})")
        if role == "swap":
            mode = prompt("Swap mode for config.sh (zram | swapfile | zram+swapfile)", default=self.swap_mode)
            if mode in ("zram", "swapfile", "zram+swapfile"):
                self.swap_mode = mode

    def save_config(self) -> None:
        updates: Dict[str, str] = {}
        root_assign = self.assignments.get("root")
        home_assign = self.assignments.get("home")
        efi_assign = self.assignments.get("efi")

        if root_assign and root_assign.get("label"):
            updates["IROOT_PARTITION_LABEL"] = root_assign["label"]
        if home_assign and home_assign.get("label"):
            updates["IHOME_PARTITION_LABEL"] = home_assign["label"]
        if efi_assign and efi_assign.get("path"):
            updates["IEFI_PARTITION"] = efi_assign["path"]
        updates["ISWAP_TYPE"] = self.swap_mode

        if not updates:
            print("Nothing to write to config.sh.")
            return
        self._write_config_vars(updates)
        print("Updated config.sh with:", ", ".join(updates.keys()))

    def _write_config_vars(self, updates: Dict[str, str]) -> None:
        if not CONFIG_PATH.exists():
            raise FileNotFoundError(f"{CONFIG_PATH} not found")
        with CONFIG_PATH.open("r", encoding="utf-8") as fh:
            lines = fh.readlines()

        def fmt(name: str, value: str) -> str:
            return f'export {name}="{value}"\n'

        for name, value in updates.items():
            pattern = re.compile(rf"^\s*export\s+{re.escape(name)}=.*$")
            replaced = False
            for idx, line in enumerate(lines):
                if pattern.match(line):
                    lines[idx] = fmt(name, value)
                    replaced = True
                    break
            if not replaced:
                if lines and not lines[-1].endswith("\n"):
                    lines[-1] += "\n"
                lines.append(fmt(name, value))

        with CONFIG_PATH.open("w", encoding="utf-8") as fh:
            fh.writelines(lines)

    # --- Loop ---
    def loop(self) -> None:
        menu = """
-- March Partition Planner (CLI) --
[1] Disk      [2] List
[3] Create    [4] Delete
[5] Resize    [6] Move (abs)
[7] Move (rel)[8] Label
[9] Assign    [10] Plan
[A] Apply     [S] Save config
[R] Refresh   [Q] Quit
"""
        while True:
            print(menu)
            self.show_assignments()
            choice = prompt("Choose")
            if not choice:
                continue
            c = choice.lower()
            if c == "1":
                self.choose_disk()
            elif c == "2":
                self.list_partitions()
            elif c == "3":
                self.add_create()
            elif c == "4":
                self.add_delete()
            elif c == "5":
                self.add_resize()
            elif c == "6":
                self.add_move()
            elif c == "7":
                self.add_move_relative()
            elif c == "8":
                self.add_label()
            elif c == "9":
                self.assign_role()
            elif c == "10":
                self.show_plan()
            elif c == "a":
                self.apply_plan()
            elif c == "s":
                self.save_config()
            elif c == "r":
                self.refresh()
                print("Refreshed lsblk.")
            elif c == "q":
                return
            else:
                print("Unknown choice.")


def main() -> None:
    try:
        planner = Planner()
    except FileNotFoundError as exc:
        print(f"Missing dependency: {exc}")
        return
    planner.loop()


if __name__ == "__main__":
    main()
