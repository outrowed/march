from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from os import PathLike
from typing import override

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
    synced_packages: list[PackageSynced] = field(default_factory=list)
    removed_packages: list[Package | PackageSynced] = field(default_factory=list)

    def add_packages(self, *package_or_str: str | Package):
        packages = Package.to_packages(package_or_str)
        
        # _ = os.system(f"{self.pacman_cmd} -S {str.join(" ", (pac.resolve_sync(self) for pac in packages))}")

        self.added_packages.extend(packages)

    def remove_packages(self, *package_or_str: str | Package):
        packages = Package.to_packages(package_or_str)

        self.removed_packages.extend(packages)
        
        for pac in packages: self.added_packages.remove(pac)

    def sync_packages(self):
        ...

    def unsync_packages(self):
        ...

    def pacstrap(self, _target: str | PathLike[str], _package_or_str: list[str | Package]):
        ...

    def add_repo(self, _repo_name: str, _repo_urls: list[str]):
        ...