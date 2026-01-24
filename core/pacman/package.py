
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date
from enum import Enum
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
