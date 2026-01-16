import logging
import subprocess

from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from os import PathLike
from typing import override

from core.config import get_dry_run, get_pacman_output

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

    def resolve_sync(self, _pacman: "Pacman"):
        return self.name

    @staticmethod
    def to_packages(package_or_str: Iterable["str | Package"]) -> tuple["Package"]:
        packages: list[Package] = []

        for pac in package_or_str:
            if pac is str:
                packages.append(Package(pac))
            elif pac is Package:
                packages.append(pac)
            else:
                raise ValueError("invalid type", type(pac), pac)
        
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
    synced_packages: list[Package] = field(default_factory=list)
    removed_packages: list[Package] = field(default_factory=list)

    def add_packages(self, *package_or_str: str | Package):
        packages = Package.to_packages(package_or_str)
        
        self.added_packages.extend(packages)

    def remove_packages(self, *package_or_str: str | Package):
        packages = Package.to_packages(package_or_str)

        self.removed_packages.extend(packages)
        
        for pac in packages:
            self.added_packages.remove(pac)

    def sync_packages(self, *package_or_str: str | Package):
        self.add_packages(*package_or_str)

        resolved_packages = " ".join(
            pac.resolve_sync(self)
                for pac in self.added_packages
        )

        if not get_dry_run():
            pacman_log = logging.getLogger(self.pacman_cmd)
            
            with subprocess.Popen(
                [self.pacman_cmd, "-S", "--needed", "--noconfirm", resolved_packages],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            ) as proc:
                if proc.stdout is not None:
                    for line in proc.stdout:
                        pacman_log.info(line)

                _ = proc.wait(10_000)
            
            if proc.returncode != 0:
                pacman_log.error(f"Process finished with errors (return code {proc.returncode})")

        self.synced_packages.extend(self.added_packages)

    def unsync_packages(self, *package_or_str: str | Package):
        packages = Package.to_packages(package_or_str)

        self.removed_packages.extend(packages)

        for pac in packages:
            self.synced_packages.remove(pac)

    def pacstrap(self, _target: str | PathLike[str], _package_or_str: list[str | Package]):
        ...