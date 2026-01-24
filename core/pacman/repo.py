
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

class RepositoryKey(Enum):
    ARCH_LINUX_OFFICIAL = "arch-linux-official"

@dataclass(kw_only=True)
class Repository:
    name: str
    aliases: list[str]
    include: Path
    key: str | RepositoryKey
    keyserver_url: str | RepositoryKey
    external_package_urls: list[str]

type RepositoryList = list[Repository]