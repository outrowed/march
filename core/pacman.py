import logging

from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from os import PathLike
from typing import override

from core.util import subprocess_open

log = logging.getLogger(__name__)

class PackageVersion(Enum):
    LATEST = "latest"

class PackageArch(Enum):
    X86_64 = "x86_64"

@dataclass
class Package:
    name: str
    version: str | PackageVersion = PackageVersion.LATEST
    arch: PackageArch = PackageArch.X86_64
    aur: bool = False

    @staticmethod
    def from_pacstr(package_or_str: str | Package) -> Package:
        pacstr = package_or_str

        if pacstr is str:
            return Package(pacstr)
        elif pacstr is Package:
            return pacstr
        else:
            raise ValueError(f"invalid package string: {pacstr}", type(pacstr), pacstr)

    @staticmethod
    def from_pacstr_iter(package_or_str: Iterable[str | Package]) -> tuple["Package"]:
        packages: list[Package] = []

        for pac in package_or_str:
            packages.append(Package.from_pacstr(pac))
        
        return tuple[Package](packages)

    @override
    def __str__(self) -> str:
        return f"{self.name}_{self.version}_{self.arch}{"_aur" if self.aur else ""}"

    @override
    def __hash__(self) -> int:
        return hash(self.__str__())
                
@dataclass(kw_only=True)
class PackageSynced(Package):
    synced_id: str
    synced_url: str
    last_synced: date

    def equal_package(self, other_package: Package):
        return hash(super()) == hash(other_package)

    @override
    def __str__(self) -> str:
        return self.synced_id

    @override
    def __hash__(self) -> int:
        return hash(self.synced_id)

@dataclass
class Pacman:
    pacman_cmd: str = "pacman"
    pacstrap_cmd: str = "pacstrap"
    added_packages: list[Package] = field(default_factory=list)
    synced_packages: list[PackageSynced] = field(default_factory=list)
    removed_packages: list[Package | PackageSynced] = field(default_factory=list)

    def add_packages(self, *package_or_str: str | Package):
        packages = Package.from_pacstr_iter(package_or_str)
        
        self.added_packages.extend(packages)

    def remove_packages(self, *package_or_str: str | Package):
        packages = Package.from_pacstr_iter(package_or_str)

        self.removed_packages.extend(packages)
        
        for pac in packages:
            self.added_packages.remove(pac)

    def resolve_sync(self, package_or_str: str | Package):
        package = Package.from_pacstr(package_or_str)
        return PackageSynced(
            name=package.name,
            version=package.version,
            arch=package.arch,
            aur=package.aur,
            synced_id=package.name,
            synced_url=f"https://example.org/package/{package.name}",
            last_synced=datetime.now()
        )

    def sync_packages(self, *package_or_str: str | Package):
        self.add_packages(*package_or_str)

        resolved_packages = (
            self.resolve_sync(pac) for pac in self.added_packages
        )

        subprocess_open(
            self.pacman_cmd,
            "-S", "--needed", "--noconfirm",
            *(str(pac) for pac in resolved_packages)
        )

        self.synced_packages.extend(resolved_packages)

    def unsync_packages(self, *package_or_str: str | Package):
        self.remove_packages(*package_or_str)

        packages = Package.from_pacstr_iter(package_or_str)

        subprocess_open(
            self.pacman_cmd,
            "-Rs",
            *(str(pac) for pac in packages)
        )

        for pac in packages:
            removed_synced_packages = (
                synced_pac for synced_pac in self.synced_packages
                    if synced_pac.name == pac.name
            )
            for removed_pac in removed_synced_packages:
                self.synced_packages.remove(removed_pac)

    def pacstrap(self, _target: str | PathLike[str], _package_or_str: list[str | Package]):
        ...