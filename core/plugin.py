from dataclasses import dataclass
from core.hook import Hooker

@dataclass
class Plugin:
    name: str
    hooker: Hooker