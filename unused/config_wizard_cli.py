#!/usr/bin/env python3
"""
CLI menu replacement for config-wizard.sh and users-wizard.sh, with a link to the partitions wizard.

Run from repo root: python3 config_wizard_cli.py
Dependencies: python3 stdlib, bash, openssl; partitions wizard needs lsblk/parted/sgdisk.
"""

from __future__ import annotations

import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Dict, List

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.sh"
PASSWORD_DIR = BASE_DIR / "passwords"
PART_WIZARD = BASE_DIR / "partitions-wizard.py"

STRING_FIELDS = [
    "ISUPER_USER",
    "IHOSTNAME",
    "ITIMEZONE",
    "IKEYMAP",
    "INTP",
    "INTP_FALLBACK",
    "IEFI_PARTITION",
    "IEFI_LINUX_DIRNAME",
    "IROOT_PARTITION_LABEL",
    "IHOME_PARTITION_LABEL",
    "ISYSTEMD_BOOT_ARCH_LABEL",
    "ISYSTEMD_BOOT_EFI_LABEL",
    "IUKI_LABEL",
    "IUKI_EXEC",
    "IKERNEL_CMDLINE",
    "IKERNEL_ZSWAP_CMDLINE",
]

ARRAY_FIELDS = [
    "ILOCALE_GEN_LIST",
    "ILOCALE_CONF",
]

CHOICES = {
    "ISWAP_TYPE": ["zram", "swapfile", "zram+swapfile"],
    "IBOOTLOADER": ["systemd-boot", "uki"],
    "IINITRAMFS_TYPE": ["systemd", "busybox"],
    "IEXPLICIT_RESUME_ARGS": ["true", "false"],
}


# -------------------- Config parsing/writing -------------------- #
def parse_config() -> Dict[str, object]:
    names = STRING_FIELDS + ARRAY_FIELDS + list(CHOICES.keys())
    name_str = " ".join(shlex.quote(v) for v in names)
    cmd = ["bash", "-lc", f"source config.sh; for v in {name_str}; do declare -p \"$v\" 2>/dev/null; done"]
    proc = subprocess.run(cmd, cwd=BASE_DIR, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr or "Failed to parse config.sh")
    values: Dict[str, object] = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line.startswith("declare"):
            continue
        m = re.match(r"declare\s+-([a-zA-Z]+)\s+([A-Za-z0-9_]+)=(.*)", line)
        flags = ""
        if not m:
            m = re.match(r"declare\s+--\s+([A-Za-z0-9_]+)=(.*)", line)
            if not m:
                continue
        else:
            flags = m.group(1)
        name = m.group(2)
        val = m.group(3)
        if "a" in flags and val.startswith("("):
            entries = re.findall(r'"((?:[^"\\]|\\.)*)"', val)
            values[name] = [bytes(entry, "utf-8").decode("unicode_escape") for entry in entries]
        else:
            if val.startswith('"') and val.endswith('"'):
                val = val[1:-1]
                val = bytes(val, "utf-8").decode("unicode_escape")
            values[name] = val
    for key in ARRAY_FIELDS:
        values.setdefault(key, [])
    for key, opts in CHOICES.items():
        values.setdefault(key, opts[0])
    return values


def escape_val(val: str) -> str:
    return val.replace("\\", "\\\\").replace('"', '\\"')


def format_array(name: str, values: List[str]) -> List[str]:
    lines = [f"{name}=("]
    for v in values:
        lines.append(f'    "{escape_val(v)}"')
    lines.append(")")
    return lines


def rewrite_config(updates: Dict[str, object]) -> None:
    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"{CONFIG_PATH} not found")
    with CONFIG_PATH.open("r", encoding="utf-8") as fh:
        lines = fh.readlines()

    def is_var_line(line: str, var: str) -> bool:
        return re.match(rf"^\s*(export\s+)?{re.escape(var)}\b", line) is not None

    out: List[str] = []
    skip_array = False
    handled = set()
    i = 0
    while i < len(lines):
        line = lines[i]
        if skip_array:
            if line.strip().endswith(")"):
                skip_array = False
            i += 1
            continue
        matched_var = next((v for v in updates if is_var_line(line, v)), None)
        if matched_var:
            handled.add(matched_var)
            val = updates[matched_var]
            if isinstance(val, list):
                out.extend(format_array(matched_var, val))
                out.append("\n")
                skip_array = True
                i += 1
                while i < len(lines) and not lines[i].strip().endswith(")"):
                    i += 1
                i += 1
            else:
                out.append(f'export {matched_var}="{escape_val(str(val))}"\n')
                i += 1
        else:
            out.append(line)
            i += 1

    for var, val in updates.items():
        if var in handled:
            continue
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        if isinstance(val, list):
            out.extend(format_array(var, val))
            out.append("\n")
        else:
            out.append(f'export {var}="{escape_val(str(val))}"\n')

    with CONFIG_PATH.open("w", encoding="utf-8") as fh:
        fh.writelines(out)


# -------------------- Helpers -------------------- #
def prompt(msg: str, default: str | None = None) -> str:
    hint = f" [{default}]" if default is not None else ""
    ans = input(f"{msg}{hint}: ").strip()
    return ans if ans else (default or "")


def choose_from_list(title: str, items: List[str], default_idx: int = 0) -> str:
    print(f"\n{title}")
    for idx, item in enumerate(items):
        mark = "*" if idx == default_idx else " "
        print(f"  {idx}){mark} {item}")
    choice = prompt("Select", str(default_idx))
    try:
        return items[int(choice)]
    except Exception:
        return items[default_idx]


def edit_array(name: str, values: List[str]) -> List[str]:
    arr = values[:]
    while True:
        print(f"\n{name}:")
        if arr:
            for idx, v in enumerate(arr):
                print(f"  {idx}) {v}")
        else:
            print("  (empty)")
        action = prompt("[a]dd/[r]emove/[c]lear/[d]one", "d").lower()
        if action == "a":
            val = prompt("Value to add")
            if val:
                arr.append(val)
        elif action == "r":
            idx = prompt("Index to remove", "")
            if idx.isdigit() and int(idx) < len(arr):
                arr.pop(int(idx))
        elif action == "c":
            arr.clear()
        elif action == "d":
            return arr


# -------------------- User management -------------------- #
def list_users() -> List[str]:
    PASSWORD_DIR.mkdir(exist_ok=True)
    return sorted([p.name for p in PASSWORD_DIR.glob("*") if p.is_file()])


def add_user() -> None:
    username = prompt("Username")
    if not username:
        print("Username required.")
        return
    groups = prompt("Groups (comma-separated, optional)")
    pwd1 = prompt("Password")
    pwd2 = prompt("Confirm password")
    if pwd1 != pwd2:
        print("Passwords do not match.")
        return
    filename = username if not groups else f"{username}+{groups.replace(' ', '')}"
    try:
        proc = subprocess.run(["openssl", "passwd", "-6", pwd1], text=True, capture_output=True, check=True)
    except subprocess.CalledProcessError as exc:
        print("openssl failed:", exc.stderr or exc)
        return
    PASSWORD_DIR.mkdir(exist_ok=True)
    (PASSWORD_DIR / filename).write_text(proc.stdout.strip() + "\n", encoding="utf-8")
    print(f"Saved {filename}")


def delete_user() -> None:
    users = list_users()
    if not users:
        print("No entries.")
        return
    for idx, u in enumerate(users):
        print(f"  {idx}) {u}")
    choice = prompt("Index to delete")
    if not choice.isdigit() or int(choice) >= len(users):
        print("Invalid choice.")
        return
    target = PASSWORD_DIR / users[int(choice)]
    if prompt(f"Delete {target.name}? (y/N)", "n").lower().startswith("y"):
        target.unlink(missing_ok=True)
        print("Deleted.")


# -------------------- Menus -------------------- #
def show_config(values: Dict[str, object]) -> None:
    print("\nCurrent config values:")
    for key in STRING_FIELDS + list(CHOICES.keys()) + ARRAY_FIELDS:
        val = values.get(key, "")
        if isinstance(val, list):
            print(f"  {key}:")
            for item in val:
                print(f"    - {item}")
        else:
            print(f"  {key}: {val}")


def edit_config(values: Dict[str, object]) -> Dict[str, object]:
    vals = values.copy()
    while True:
        print(
            """
-- Config Editor --
1) Set single value
2) Set swap type
3) Set bootloader
4) Set initramfs type
5) Toggle explicit resume args
6) Edit locale.gen list
7) Edit locale.conf entries
8) Show current values
Q) Back
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            print("Known fields:")
            for idx, key in enumerate(STRING_FIELDS):
                print(f"  {idx}) {key}")
            idx = prompt("Index", "")
            if idx.isdigit() and int(idx) < len(STRING_FIELDS):
                key = STRING_FIELDS[int(idx)]
                vals[key] = prompt(f"{key}", str(vals.get(key, "")))
        elif choice == "2":
            vals["ISWAP_TYPE"] = choose_from_list("Swap type", CHOICES["ISWAP_TYPE"], CHOICES["ISWAP_TYPE"].index(vals.get("ISWAP_TYPE", CHOICES["ISWAP_TYPE"][0])))
        elif choice == "3":
            vals["IBOOTLOADER"] = choose_from_list("Bootloader", CHOICES["IBOOTLOADER"], CHOICES["IBOOTLOADER"].index(vals.get("IBOOTLOADER", CHOICES["IBOOTLOADER"][0])))
        elif choice == "4":
            vals["IINITRAMFS_TYPE"] = choose_from_list("Initramfs type", CHOICES["IINITRAMFS_TYPE"], CHOICES["IINITRAMFS_TYPE"].index(vals.get("IINITRAMFS_TYPE", CHOICES["IINITRAMFS_TYPE"][0])))
        elif choice == "5":
            current = vals.get("IEXPLICIT_RESUME_ARGS", "false")
            vals["IEXPLICIT_RESUME_ARGS"] = "false" if current == "true" else "true"
            print("Set IEXPLICIT_RESUME_ARGS ->", vals["IEXPLICIT_RESUME_ARGS"])
        elif choice == "6":
            vals["ILOCALE_GEN_LIST"] = edit_array("locale.gen entries", vals.get("ILOCALE_GEN_LIST", []))
        elif choice == "7":
            vals["ILOCALE_CONF"] = edit_array("locale.conf entries", vals.get("ILOCALE_CONF", []))
        elif choice == "8":
            show_config(vals)
        elif choice == "q":
            return vals


def manage_users() -> None:
    while True:
        print(
            """
-- Users --
1) List entries
2) Add/update entry
3) Delete entry
Q) Back
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            users = list_users()
            if users:
                for u in users:
                    print("  ", u)
            else:
                print("No entries.")
        elif choice == "2":
            add_user()
        elif choice == "3":
            delete_user()
        elif choice == "q":
            return


def open_partitions_wizard() -> None:
    if not PART_WIZARD.exists():
        print(f"{PART_WIZARD} not found.")
        return
    print("Opening partitions wizard (separate process)...")
    subprocess.Popen(["python3", str(PART_WIZARD)], cwd=BASE_DIR)


def main_menu() -> None:
    try:
        values = parse_config()
    except Exception as exc:  # noqa: BLE001
        print("Error loading config:", exc)
        values = {}
    dirty = False
    while True:
        print(
            """
== March Config Wizard (CLI) ==
1) Edit config
2) Manage users (passwords)
3) Open partitions wizard
4) Show current config
S) Save config
R) Reload from config.sh
Q) Quit
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            values = edit_config(values)
            dirty = True
        elif choice == "2":
            manage_users()
        elif choice == "3":
            open_partitions_wizard()
        elif choice == "4":
            show_config(values)
        elif choice == "s":
            try:
                rewrite_config(values)
                dirty = False
                print("Saved to config.sh")
            except Exception as exc:  # noqa: BLE001
                print("Save failed:", exc)
        elif choice == "r":
            try:
                values = parse_config()
                dirty = False
                print("Reloaded config.sh")
            except Exception as exc:  # noqa: BLE001
                print("Reload failed:", exc)
        elif choice == "q":
            if dirty and prompt("Unsaved changes. Quit anyway? (y/N)", "n").lower().startswith("y"):
                return
            if not dirty:
                return


if __name__ == "__main__":
    main_menu()
