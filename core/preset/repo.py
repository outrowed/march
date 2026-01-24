
from pathlib import Path
from core.pacman.repo import Repository, RepositoryKey

## Arch Linux official

core = Repository(
    name="core",
    aliases=[],
    include=Path("/etc/pacman.d/mirrorlist"),
    key=RepositoryKey.ARCH_LINUX_OFFICIAL,
    keyserver_url=RepositoryKey.ARCH_LINUX_OFFICIAL,
    external_package_urls=[]
)

extra = Repository(
    name="extra",
    aliases=[],
    include=Path("/etc/pacman.d/mirrorlist"),
    key=RepositoryKey.ARCH_LINUX_OFFICIAL,
    keyserver_url=RepositoryKey.ARCH_LINUX_OFFICIAL,
    external_package_urls=[]
)

multilib = Repository(
    name="multilib",
    aliases=[],
    include=Path("/etc/pacman.d/mirrorlist"),
    key=RepositoryKey.ARCH_LINUX_OFFICIAL,
    keyserver_url=RepositoryKey.ARCH_LINUX_OFFICIAL,
    external_package_urls=[]
)

## External

cachyos = Repository(
    name="cachyos",
    aliases=[],
    include=Path("/etc/pacman.d/cachyos-mirrorlist"),
    key="F3B607488DB35A47",
    keyserver_url="keyserver.ubuntu.com",
    external_package_urls=[
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.1.0.r7.gb9f7d4a-3-x86_64.pkg.tar.zst'
    ]
)

cachyos_v3 = Repository(
    name="cachyos-v3",
    aliases=[
        "cachyos-core-v3",
        "cachyos-extra-v3",
    ],
    include=Path("/etc/pacman.d/cachyos-v3-mirrorlist"),
    key="F3B607488DB35A47",
    keyserver_url="keyserver.ubuntu.com",
    external_package_urls=[
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.1.0.r7.gb9f7d4a-3-x86_64.pkg.tar.zst'
    ]
)

cachyos_v4 = Repository(
    name="cachyos-v4",
    aliases=[
        "cachyos-core-v4",
        "cachyos-extra-v4",
    ],
    include=Path("/etc/pacman.d/cachyos-v4-mirrorlist"),
    key="F3B607488DB35A47",
    keyserver_url="keyserver.ubuntu.com",
    external_package_urls=[
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst',
        'https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.1.0.r7.gb9f7d4a-3-x86_64.pkg.tar.zst'
    ]
)

chaotic_aur = Repository(
    name="chaotic-aur",
    aliases=[],
    include=Path("/etc/pacman.d/chaotic-mirrorlist"),
    key="3056513887B78AEB",
    keyserver_url="keyserver.ubuntu.com",
    external_package_urls=[
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst',
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    ]
)