#!/usr/bin/env python3
"""
March installer front-end (CLI).

Tasks:
- Set hostname
- Manage locale lists (locale.gen and locale.conf)
- Manage user password hashes (users wizard)
- Open partition wizard
- Open advanced config editor (config-wizard.sh)
- Optionally launch ./install.sh

Run from repo root on the Arch ISO: python3 installer.py
Dependencies: python3 stdlib, bash, openssl (for password hashes), lsblk/parted/sgdisk for the partition wizard.
"""

from __future__ import annotations

import re
import importlib.util
import shlex
import subprocess
from pathlib import Path
from typing import Dict, List

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.sh"
PASSWORD_DIR = BASE_DIR / "passwords"

LOCALE_ARRAYS = ["ILOCALE_GEN_LIST", "ILOCALE_CONF"]


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


# -------------------- Config parsing/writing -------------------- #
def parse_config() -> Dict[str, object]:
    names = [
        "IHOSTNAME",
        "ISWAP_TYPE",
        "IEFI_PARTITION",
        "IROOT_PARTITION_LABEL",
        "IHOME_PARTITION_LABEL",
        "ILOCALE_GEN_LIST",
        "ILOCALE_CONF",
    ]
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
    for key in LOCALE_ARRAYS:
        values.setdefault(key, [])
    values.setdefault("IHOSTNAME", "")
    values.setdefault("IROOT_PARTITION_LABEL", "")
    values.setdefault("IHOME_PARTITION_LABEL", "")
    values.setdefault("IEFI_PARTITION", "")
    values.setdefault("ISWAP_TYPE", "zram+swapfile")
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


def user_menu() -> None:
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


# -------------------- Actions -------------------- #
def set_hostname(values: Dict[str, object]) -> Dict[str, object]:
    values["IHOSTNAME"] = prompt("Hostname", str(values.get("IHOSTNAME", "")))
    return values


def edit_locales(values: Dict[str, object]) -> Dict[str, object]:
    values["ILOCALE_GEN_LIST"] = edit_array("locale.gen entries", values.get("ILOCALE_GEN_LIST", []))
    values["ILOCALE_CONF"] = edit_array("locale.conf entries", values.get("ILOCALE_CONF", []))
    return values


def set_default_locale(values: Dict[str, object]) -> Dict[str, object]:
    supported = load_supported_locales()
    current = current_lang(values) or "en_US.UTF-8"
    filter_str = prompt("Filter locales (e.g., en_US)", current.split(".")[0])
    if not filter_str:
        print("Cancelled.")
        return values
    filtered = [loc for loc in supported if filter_str.lower() in loc.lower()] if supported else []
    if filtered:
        print("\nMatched locales (first 20):")
        for idx, loc in enumerate(filtered[:20]):
            mark = "*" if loc == current else " "
            print(f"  {idx}){mark} {loc}")
        choice = prompt("Pick index or enter locale", "0")
        if not choice:
            print("Cancelled.")
            return values
        if choice.isdigit() and int(choice) < len(filtered[:20]):
            chosen = filtered[int(choice)]
        else:
            chosen = choice or current
    else:
        chosen = prompt("Enter locale (e.g., en_US.UTF-8)", current)
        if not chosen:
            print("Cancelled.")
            return values

    # Ensure in locale.gen list
    gen_list = values.get("ILOCALE_GEN_LIST", [])
    if chosen not in gen_list:
        gen_list.append(chosen)
        values["ILOCALE_GEN_LIST"] = gen_list
        print(f"Added {chosen} to ILOCALE_GEN_LIST")

    # Update LANG in locale.conf entries
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


def load_partition_planner():
    module_path = BASE_DIR / "partitions-wizard.py"
    if not module_path.exists():
        raise FileNotFoundError(f"{module_path} not found")
    spec = importlib.util.spec_from_file_location("partitions_wizard_inline", module_path)
    if spec is None or spec.loader is None:
        raise ImportError("Unable to load partitions-wizard.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not hasattr(module, "Planner"):
        raise ImportError("Planner class not found in partitions-wizard.py")
    return module.Planner


def open_partitions_wizard_inline(values: Dict[str, object]) -> Dict[str, object]:
    try:
        Planner = load_partition_planner()
        planner = Planner()
    except Exception as exc:  # noqa: BLE001
        print("Unable to load partition planner:", exc)
        return values
    # Preload assignments from config
    root_label = values.get("IROOT_PARTITION_LABEL", "")
    home_label = values.get("IHOME_PARTITION_LABEL", "")
    planner.assignments["root"] = {"path": "", "label": root_label} if root_label else None
    planner.assignments["home"] = {"path": "", "label": home_label} if home_label else None
    planner.assignments["efi"] = None
    planner.assignments["swap"] = None
    planner.swap_mode = values.get("ISWAP_TYPE", planner.swap_mode)
    planner.loop()
    # Pull back labels and EFI path if set
    if planner.assignments.get("root", {}).get("label"):
        values["IROOT_PARTITION_LABEL"] = planner.assignments["root"]["label"]
    if planner.assignments.get("home", {}).get("label"):
        values["IHOME_PARTITION_LABEL"] = planner.assignments["home"]["label"]
    if planner.assignments.get("efi", {}).get("path"):
        values["IEFI_PARTITION"] = planner.assignments["efi"]["path"]
    values["ISWAP_TYPE"] = planner.swap_mode
    return values


def open_advanced_editor() -> None:
    script = BASE_DIR / "config-wizard.sh"
    if not script.exists():
        print("config-wizard.sh not found.")
        return
    subprocess.call(["bash", str(script)], cwd=BASE_DIR)


def run_installer() -> None:
    script = BASE_DIR / "install.sh"
    if not script.exists():
        print("install.sh not found.")
        return
    ok = refresh_keyring()
    if not ok:
        if not prompt("Keyring refresh failed. Continue anyway? (y/N)", "n").lower().startswith("y"):
            return
    if prompt("Run install.sh now? (y/N)", "n").lower().startswith("y"):
        subprocess.call(["bash", str(script)], cwd=BASE_DIR)


def refresh_keyring() -> None:
    print("Refreshing pacman-key (Arch keyring)...")
    cmds = [
        ["pacman-key", "--init"],
        ["pacman-key", "--populate"],
        ["pacman-key", "--refresh-keys"],
    ]
    for cmd in cmds:
        print(">", " ".join(cmd))
        result = subprocess.run(cmd, text=True)
        if result.returncode != 0:
            print("Command failed; aborting key refresh.")
            return False
    print("pacman-key refresh completed.")
    return True


# -------------------- Main menu -------------------- #
def main() -> None:
    try:
        values = parse_config()
    except Exception as exc:  # noqa: BLE001
        print("Error loading config:", exc)
        return
    while True:
        users = list_users()
        print(
            f"""
== March Installer ==
Hostname: {values.get("IHOSTNAME","")}
Default locale: {current_lang(values) or "(unset)"}
locale.gen entries: {len(values.get("ILOCALE_GEN_LIST", []))}
locale.conf entries: {len(values.get("ILOCALE_CONF", []))}
Password entries: {len(users)}

1) Set hostname
2) Set default locale
3) Edit locales
4) User wizard
5) Partition wizard

9) Run INSTALLER (install.sh)

A) Advanced menu
Q) Quit
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            values = set_hostname(values)
        elif choice == "2":
            values = set_default_locale(values)
        elif choice == "3":
            values = edit_locales(values)
        elif choice == "4":
            user_menu()
        elif choice == "5":
            values = open_partitions_wizard_inline(values)
        elif choice == "9":
            run_installer()
        elif choice == "a":
            values = advanced_menu(values)
        elif choice == "q":
            return


def advanced_menu(values: Dict[str, object]) -> Dict[str, object]:
    while True:
        print(
            """
-- Advanced --
1) Save changes to config.sh
2) Reload config.sh
3) Advanced config editor (config-wizard.sh)
Q) Back
"""
        )
        choice = prompt("Choice").lower()
        if choice == "1":
            try:
                rewrite_config(values)
                print("Saved to config.sh")
            except Exception as exc:  # noqa: BLE001
                print("Save failed:", exc)
        elif choice == "2":
            try:
                values = parse_config()
                print("Reloaded config.sh")
            except Exception as exc:  # noqa: BLE001
                print("Reload failed:", exc)
        elif choice == "3":
            open_advanced_editor()
        elif choice == "q":
            return values
    return values


if __name__ == "__main__":
    main()
