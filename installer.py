#!/usr/bin/env python3
"""
March installer front-end (CLI).

Features:
- Set hostname
- Set default locale (adds to locale.gen list and LANG in locale.conf entries)
- Manage users (replacement for users-wizard.sh)
- Mini partition wizard (set EFI path + root/home labels, swap type)

Footer actions:
- Run installer (install.sh, saving config.sh first)
- Advanced menu (launches config-wizard.sh)
- Quit
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Dict, List, Optional

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.sh"
PASSWORD_DIR = BASE_DIR / "passwords"

STRING_FIELDS = [
    "ISUPER_USER",
    "IHOSTNAME",
    "IEFI_PARTITION",
    "IROOT_PARTITION_LABEL",
    "IHOME_PARTITION_LABEL",
]

ARRAY_FIELDS = [
    "ILOCALE_GEN_LIST",
    "ILOCALE_CONF",
]

CHOICES = {
    "ISWAP_TYPE": ["zram", "swapfile", "zram+swapfile"],
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
    values.setdefault("IHOSTNAME", "")
    values.setdefault("ISUPER_USER", "")
    values.setdefault("IEFI_PARTITION", "")
    values.setdefault("IROOT_PARTITION_LABEL", "")
    values.setdefault("IHOME_PARTITION_LABEL", "")
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
def prompt(msg: str, default: Optional[str] = None) -> str:
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


# -------------------- Locale helpers -------------------- #
def load_supported_locales() -> List[str]:
    supported_file = Path("/usr/share/i18n/SUPPORTED")
    locales: List[str] = []
    if supported_file.exists():
        for line in supported_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts:
                locales.append(parts[0])
    if not locales:
        try:
            out = subprocess.check_output(["locale", "-a"], text=True)
            locales = [ln.strip() for ln in out.splitlines() if ln.strip()]
        except Exception:
            pass
    return sorted(set(locales))


def current_lang(values: Dict[str, object]) -> str:
    for entry in values.get("ILOCALE_CONF", []):
        if entry.startswith("LANG="):
            return entry.split("=", 1)[1]
    return ""


def set_default_locale(values: Dict[str, object]) -> Dict[str, object]:
    supported = load_supported_locales()
    current = current_lang(values) or "en_US.UTF-8"
    filter_str = prompt("Filter locales (e.g., en_US, blank to cancel)", current.split(".")[0])
    if not filter_str:
        print("Cancelled.")
        return values
    filtered = [loc for loc in supported if filter_str.lower() in loc.lower()] if supported else []
    if filtered:
        print("\nMatched locales (first 20):")
        for idx, loc in enumerate(filtered[:20]):
            mark = "*" if loc == current else " "
            print(f"  {idx}){mark} {loc}")
        choice = prompt("Pick index or enter locale (q to cancel)", "0")
        if choice.lower() == "q":
            print("Cancelled.")
            return values
        if choice.isdigit() and int(choice) < len(filtered[:20]):
            chosen = filtered[int(choice)]
        else:
            chosen = choice or current
    else:
        chosen = prompt("Enter locale (e.g., en_US.UTF-8, blank to cancel)", current)
    if not chosen:
        print("Cancelled.")
        return values

    gen_list = values.get("ILOCALE_GEN_LIST", [])
    if chosen not in gen_list:
        gen_list.append(chosen)
        values["ILOCALE_GEN_LIST"] = gen_list
        print(f"Added {chosen} to ILOCALE_GEN_LIST")

    conf_entries = values.get("ILOCALE_CONF", [])
    updated = False
    for i, entry in enumerate(conf_entries):
        if entry.startswith("LANG="):
            conf_entries[i] = f"LANG={chosen}"
            updated = True
            break
    if not updated:
        conf_entries.insert(0, f"LANG={chosen}")
    values["ILOCALE_CONF"] = conf_entries
    print(f"Set LANG={chosen}")
    return values


# -------------------- User management -------------------- #
def list_users() -> List[str]:
    PASSWORD_DIR.mkdir(exist_ok=True)
    return sorted([p.name for p in PASSWORD_DIR.glob("*") if p.is_file()])


def add_or_update_user(required_user: str) -> None:
    username = prompt("Username")
    if not username:
        print("Username required.")
        return
    groups = ""
    if username != "root":
        groups_input = prompt("Groups (comma-separated, optional)", "")
        groups = groups_input.replace(" ", "")
    pwd1 = prompt("Password")
    pwd2 = prompt("Confirm password")
    if pwd1 != pwd2:
        print("Passwords do not match.")
        return
    filename = username if not groups else f"{username}+{groups}"
    try:
        proc = subprocess.run(["openssl", "passwd", "-6", pwd1], text=True, capture_output=True, check=True)
    except subprocess.CalledProcessError as exc:
        print("openssl failed:", exc.stderr or exc)
        return
    PASSWORD_DIR.mkdir(exist_ok=True)
    (PASSWORD_DIR / filename).write_text(proc.stdout.strip() + "\n", encoding="utf-8")
    print(f"Saved {filename}")
    if required_user and username == required_user:
        print(f"Required user '{required_user}' now present.")
    if username == "root":
        print("Root password set.")


def delete_user(required_user: str) -> None:
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
    if required_user and target.name.startswith(required_user):
        print(f"Cannot delete required user '{required_user}'.")
        return
    if target.name.startswith("root"):
        print("Cannot delete root password entry from here.")
        return
    if prompt(f"Delete {target.name}? (y/N)", "n").lower().startswith("y"):
        target.unlink(missing_ok=True)
        print("Deleted.")


def users_menu(required_user: str) -> None:
    while True:
        users = list_users()
        root_exists = any(u.startswith("root") for u in users)
        req_exists = any(u.startswith(required_user) for u in users) if required_user else True
        print(
            f"""
-- Users --
Root password: {"set" if root_exists else "MISSING"}
Required user '{required_user or "(unset)"}': {"present" if req_exists else "missing"}

1) List entries
2) Add/update entry
3) Delete entry (non-root/non-required)
Q) Back
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            if users:
                for u in users:
                    print("  ", u)
            else:
                print("No entries.")
        elif choice == "2":
            add_or_update_user(required_user)
        elif choice == "3":
            delete_user(required_user)
        elif choice == "q":
            return


# -------------------- Partitions -------------------- #
def lsblk_rows() -> List[Dict[str, object]]:
    try:
        out = subprocess.check_output(
            ["lsblk", "--bytes", "--json", "-o", "NAME,PATH,SIZE,FSTYPE,PARTLABEL,MOUNTPOINT,TYPE"],
            text=True,
        )
        data = json.loads(out)
    except Exception:
        return []
    rows: List[Dict[str, str]] = []

    def walk(node: Dict) -> None:
        rows.append(
            {
                "name": node.get("name", ""),
                "path": node.get("path", ""),
                "size": int(node.get("size") or 0),
                "fstype": node.get("fstype") or "",
                "partlabel": node.get("partlabel") or "",
                "mountpoint": node.get("mountpoint") or "",
                "type": node.get("type") or "",
            }
        )
        for child in node.get("children", []):
            walk(child)

    for top in data.get("blockdevices", []):
        walk(top)
    return rows


def display_partitions(rows: List[Dict[str, object]]) -> None:
    parts = [r for r in rows if r.get("type") == "part"]
    if not parts:
        print("No partitions detected.")
        return
    print("\nAvailable partitions:")
    for idx, part in enumerate(parts):
        size_val = part.get("size") or 0
        size_mib = round(int(size_val) / (1024 * 1024), 1) if size_val else ""
        label = part["partlabel"] or part["fstype"]
        mount = part["mountpoint"]
        print(f"{idx}) {part['path']:<15} {size_mib:>8} MiB  {label:<15} {mount}")


def choose_partition(rows: List[Dict[str, object]], title: str, default: str = "") -> str:
    parts = [r for r in rows if r.get("type") == "part"]
    if not parts:
        print("No partitions available to select.")
        return default
    display_partitions(rows)
    mapping = {str(i): p["path"] for i, p in enumerate(parts)}
    choice = prompt(title, "")
    if choice in mapping:
        return mapping[choice]
    if choice and any(choice == p["path"] for p in parts):
        return choice
    print("No change.")
    return default


def partitions_menu(values: Dict[str, object]) -> Dict[str, object]:
    rows = lsblk_rows()
    while True:
        print(
            f"""
-- Partitions --
EFI partition: {values.get("IEFI_PARTITION") or "(unset)"}
Root PARTLABEL: {values.get("IROOT_PARTITION_LABEL") or "(unset)"}
Home PARTLABEL: {values.get("IHOME_PARTITION_LABEL") or "(unset)"}
Swap type: {values.get("ISWAP_TYPE")}

1) Show partitions
2) Set EFI partition path
3) Set root PARTLABEL
4) Set home PARTLABEL
5) Set swap type
Q) Back
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            display_partitions(rows)
        elif choice == "2":
            rows = lsblk_rows()
            values["IEFI_PARTITION"] = choose_partition(rows, "Pick EFI partition index or path", str(values.get("IEFI_PARTITION", "")))
        elif choice == "3":
            values["IROOT_PARTITION_LABEL"] = prompt("Root PARTLABEL", str(values.get("IROOT_PARTITION_LABEL", "")))
        elif choice == "4":
            values["IHOME_PARTITION_LABEL"] = prompt("Home PARTLABEL", str(values.get("IHOME_PARTITION_LABEL", "")))
        elif choice == "5":
            current = values.get("ISWAP_TYPE", CHOICES["ISWAP_TYPE"][0])
            values["ISWAP_TYPE"] = choose_from_list("Swap type", CHOICES["ISWAP_TYPE"], CHOICES["ISWAP_TYPE"].index(current))
        elif choice == "q":
            return values


# -------------------- Actions -------------------- #
def set_hostname(values: Dict[str, object]) -> Dict[str, object]:
    values["IHOSTNAME"] = prompt("Hostname", str(values.get("IHOSTNAME", "")))
    return values


def set_main_user(values: Dict[str, object]) -> Dict[str, object]:
    current = str(values.get("ISUPER_USER", ""))
    new_user = prompt("Main user (ISUPER_USER)", current)
    if new_user:
        values["ISUPER_USER"] = new_user
    else:
        print("Main user not changed.")
    return values


def save_config(values: Dict[str, object]) -> bool:
    try:
        # Merge with current config to avoid losing unrelated values.
        current = parse_config()
        merged = current.copy()
        merged.update(values)
        rewrite_config(merged)
        print("Saved to config.sh")
        return True
    except Exception as exc:  # noqa: BLE001
        print("Save failed:", exc)
        return False


def run_installer(values: Dict[str, object], dirty: bool) -> None:
    if dirty:
        if not prompt("Save config.sh before running installer? (y/N)", "y").lower().startswith("y"):
            print("Cancelled.")
            return
        if not save_config(values):
            return
    script = BASE_DIR / "install.sh"
    if not script.exists():
        print("install.sh not found.")
        return
    subprocess.call(["bash", str(script)], cwd=BASE_DIR)


def open_advanced_menu() -> None:
    script = BASE_DIR / "config-wizard.sh"
    if not script.exists():
        print("config-wizard.sh not found.")
        return
    subprocess.call(["bash", str(script)], cwd=BASE_DIR)


# -------------------- Main menu -------------------- #
def main() -> None:
    try:
        values = parse_config()
    except Exception as exc:  # noqa: BLE001
        print("Error loading config:", exc)
        return
    dirty = False
    while True:
        users = list_users()
        root_set = any(u.startswith("root") for u in users)
        main_user = values.get("ISUPER_USER", "")
        main_user_set = main_user and any(u.startswith(main_user) for u in users)
        print(
            f"""
== March Installer ==
Hostname: {values.get("IHOSTNAME","")}
Default locale: {current_lang(values) or "(unset)"}
locale.gen entries: {len(values.get("ILOCALE_GEN_LIST", []))}
locale.conf entries: {len(values.get("ILOCALE_CONF", []))}
Password entries: {len(users)} (root: {"set" if root_set else "missing"}, main user '{main_user or "(unset)"}': {"set" if main_user_set else "missing"})
EFI: {values.get("IEFI_PARTITION") or "(unset)"} | Root label: {values.get("IROOT_PARTITION_LABEL") or "(unset)"} | Home label: {values.get("IHOME_PARTITION_LABEL") or "(unset)"} | Swap: {values.get("ISWAP_TYPE")}

1) Set hostname
2) Set default locale
3) Manage users
4) Manage partitions
5) Set main user

R) Run installer (install.sh)
A) Advanced menu (config-wizard.sh)
Q) Quit
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            values = set_hostname(values)
            dirty = True
        elif choice == "2":
            values = set_default_locale(values)
            dirty = True
        elif choice == "3":
            users_menu(main_user)
        elif choice == "4":
            values = partitions_menu(values)
            dirty = True
        elif choice == "5":
            values = set_main_user(values)
            dirty = True
        elif choice == "r":
            run_installer(values, dirty)
            dirty = False
        elif choice == "a":
            open_advanced_menu()
        elif choice == "q":
            if dirty and prompt("Save changes before quitting? (y/N)", "y").lower().startswith("y"):
                if not save_config(values):
                    continue
            return


if __name__ == "__main__":
    main()
