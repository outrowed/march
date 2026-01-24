
from dataclasses import dataclass
from typing import Literal

@dataclass(kw_only=True)
class Branding:
    name: str = "Arch Linux"
    pretty_name: str = "Arch Linux"
    safe_name: str = "arch-linux"

    boot_entry_name: str = "Arch Linux"
    boot_manager_name: str = "Arch Linux Manager"

@dataclass(kw_only=True)
class UserConfig:
    wheel_user: str

    user_names: list[str] = []
    default_password: str = "default_password_lol"

@dataclass(kw_only=True)
class AutoUserConfig:
    required_users: list[str] = []
    passwords_path: str = ""

@dataclass(kw_only=True)
class LocaleConfig:
    keymap: str = "us"
    locale_gen: list[str]
    locale_conf: dict[str, str]

@dataclass(kw_only=True)
class TimeNtpConfig:
    timezone: str
    ntp_main: str
    ntp_fallback: str

@dataclass(kw_only=True)
class NetworkConfig:
    dns_handler: Literal["networkmanager", "systemd-resolved", "dnsmaq"] = "systemd-resolved"
    wifi_handler: Literal["wpa_supplicant", "iwd"] = "wpa_supplicant"

@dataclass(kw_only=True)
class DnsConfig:
    dns_main: str
    dns_fallback: str
    dns_over_tls: bool
    dns_sec: bool

@dataclass(kw_only=True)
class PacmanConfig:
    aur: Literal["paru", "yay"]
    repository_list: list[str] = [
        "core",
        "cachyos-v3",
        "cachyos",
        "chaotic-aur"
    ]
    color: bool
    parallel: int
    pacman_conf_overrides: dict[str, str]
    reflector_options: str

@dataclass(kw_only=True)
class MkinitcpioConfig:
    modules_template: list[str]
    hooks_exclude: list[str]
    initramfs_type: Literal["systemd", "busybox"]

@dataclass(kw_only=True)
class SwapConfig:
    enable: bool
    zswap_enable: bool
    size: str
    hibernation_explicit_resume_kernel_args: bool

@dataclass(kw_only=True)
class ZramConfig:
    enable: bool
    size: str

@dataclass(kw_only=True)
class BootloaderConfig:
    esp: str
    kernel_cmdline: str
    # systemd-boot or grub
    timeout: int

@dataclass(kw_only=True)
class Config:
    default_hostname: str

    branding: Branding
