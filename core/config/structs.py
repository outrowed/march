from dataclasses import dataclass, field
from typing import Literal


@dataclass(kw_only=True)
class BrandingConfig:
    name: str
    pretty_name: str
    safe_name: str
    boot_entry_name: str
    boot_manager_name: str

@dataclass(kw_only=True)
class UsersConfig:
    wheel_user: str
    user_names: list[str] = field(default_factory=list)
    default_password: str

@dataclass(kw_only=True)
class LocalizationConfig:
    keymap: str
    locale_gen: list[str]
    locale_conf: dict[str, str]

@dataclass(kw_only=True)
class NtpConfig:
    main: str
    fallback: str

@dataclass(kw_only=True)
class TimeDateConfig:
    timezone: str
    ntp: NtpConfig

@dataclass(kw_only=True)
class DnsConfig:
    backend: Literal["networkmanager", "systemd-resolved", "dnsmasq"]
    main: str
    fallback: str
    over_tls: bool
    sec: bool

@dataclass(kw_only=True)
class NetworkConfig:
    backend: Literal["networkmanager", "systemd-networkd"]
    wifi_backend: Literal["wpa_supplicant", "iwd"]
    dns: DnsConfig

@dataclass(kw_only=True)
class TargetPartitionConfig:
    query: str
    label: str
    fs: str
    size: str | None = None
    fit_size: str | None = None
    reformat: bool | None = None

@dataclass(kw_only=True)
class PartitionTargetConfig:
    esp: TargetPartitionConfig
    root: TargetPartitionConfig
    home: TargetPartitionConfig

@dataclass(kw_only=True)
class PartitionConfig:
    reformat: bool
    create_if_not_exist: bool
    partition_order: list[str]
    target: PartitionTargetConfig

@dataclass(kw_only=True)
class PacmanConfig:
    color: bool
    parallel: int
    repository_list: list[str]
    aur: Literal["paru", "yay"]
    reflector_options: str
    reflector_save: str

@dataclass(kw_only=True)
class MkinitcpioConfig:
    initramfs_type: Literal["systemd", "busybox"]
    hooks_exclude: list[str] = field(default_factory=list)
    module_templates: list[str] = field(default_factory=list)

@dataclass(kw_only=True)
class ZramConfig:
    enable: bool
    size: str

@dataclass(kw_only=True)
class SwapConfig:
    enable: bool
    zswap: bool
    size: str
    explicit_resume_kernel_args: bool
    zram: ZramConfig

@dataclass(kw_only=True)
class SystemdBootConfig:
    enable: bool
    timeout: int

@dataclass(kw_only=True)
class UkiConfig:
    enable: bool

@dataclass(kw_only=True)
class BootloaderConfig:
    kernel_options: str
    systemd_boot: SystemdBootConfig
    uki: UkiConfig

@dataclass(kw_only=True)
class MarchConfig:
    default_hostname: str
    branding: BrandingConfig
    users: UsersConfig
    localization: LocalizationConfig
    timedate: TimeDateConfig
    network: NetworkConfig
    partition: PartitionConfig
    pacman: PacmanConfig
    mkinitcpio: MkinitcpioConfig
    swap: SwapConfig
    bootloader: BootloaderConfig