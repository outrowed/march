
from dataclasses import dataclass
from typing import TYPE_CHECKING, Callable

if TYPE_CHECKING:
    from types import FunctionType
    from core.frame import RunningFrame

type HookFunc = Callable[[RunningFrame], None]

@dataclass
class Hook:
    label: str
    func: HookFunc

class Hooker:
    funcs: dict[str, HookFunc] = {}

    def __init__(self) -> None:
        pass

    def hook(self, label: str) -> Callable[[HookFunc], HookFunc]:
        def on_wrap(func: FunctionType):
            self.funcs[label] = func
            return func
        return on_wrap

    def generate_hooks(self):
        return (Hook(label, func) for label, func in self.funcs.items())
