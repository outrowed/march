import logging

from dataclasses import dataclass, field
from datetime import datetime
from os import PathLike
from pathlib import Path

from core.pacman.package import Package, PackageSynced
from core.util import subprocess_open

log = logging.getLogger(__name__)

@dataclass
class Pacman:
    pacman_base_args: list[str] = field(default_factory=lambda: ["pacman"])
    pacstrap_base_args: list[str] = field(default_factory=lambda: ["pacstrap"])
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
            *self.pacman_base_args,
            "-S", "--needed", "--noconfirm",
            *(str(pac) for pac in resolved_packages)
        )

        self.synced_packages.extend(resolved_packages)

    def unsync_packages(self, *package_or_str: str | Package):
        self.remove_packages(*package_or_str)

        packages = Package.from_pacstr_iter(package_or_str)

        subprocess_open(
            *self.pacman_base_args,
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

    def pacstrap(self, target: str | PathLike[str], package_or_str: list[str | Package]):
        self.add_packages(*package_or_str)

        resolved_packages = (
            self.resolve_sync(pac) for pac in self.added_packages
        )

        subprocess_open(
            *self.pacstrap_base_args,
            "-K",
            Path(target).resolve().as_posix(),
            *(str(pac) for pac in resolved_packages)
        )

        self.synced_packages.extend(resolved_packages)