from dataclasses import dataclass
from typing import TYPE_CHECKING

from core.pacman import Pacman

if TYPE_CHECKING:
    from core.hook import Hook
    from core.plugin import Plugin

@dataclass(kw_only=True)
class Frame:
    plugins: list[Plugin] = []

class RunningFrame(Frame):
    pacman: Pacman = Pacman()
    plugin_hooks: tuple[tuple[Plugin, Hook]]

    def __init__(self) -> None:
        super().__init__()
        self.load_plugin_hooks()

    def load_plugin_hooks(self):
        plugin_hooks: list[tuple[Plugin, Hook]] = []

        for plugin in self.plugins:
            for hook in plugin.hooker.generate_hooks():
                plugin_hooks.append((plugin, hook))

        self.plugin_hooks = tuple[tuple[Plugin, Hook]](plugin_hooks)

    def dispatch_hook(self, label: str):
        for plugin, hook in self.plugin_hooks:
            if hook.label == label:
                print(f"dispatch {plugin.name}:{hook.label}")
                hook.func(self)