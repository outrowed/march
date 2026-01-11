from dataclasses import dataclass
from core.hook import Hooker

@dataclass(kw_only=True)
class Plugin:
    name: str
    init_hook: str
    hooker: Hooker