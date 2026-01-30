
from enum import Enum
from pathlib import Path
import tomli_w
from pydantic import BaseModel

class RepositoryKey(Enum):
    ARCH_LINUX_OFFICIAL = "arch-linux-official"

class Repository(BaseModel):
    name: str
    aliases: list[str]
    include: Path
    key: str | RepositoryKey
    keyserver_url: str | RepositoryKey
    external_package_urls: list[str]

    def to_toml(self) -> str:
        # mode='json' converts Path to str and Enum to value automatically
        data = self.model_dump(mode='json', exclude={'name'})
        return tomli_w.dumps({self.name: data})

type RepositoryList = list[Repository]