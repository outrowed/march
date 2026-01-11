from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

from core.pacman import Pacman

if TYPE_CHECKING:
    from core.hook import Hook
    from core.plugin import Plugin

@dataclass(kw_only=True)
class Frame[Dict: Mapping[str, Any] = Any]:
    pacman: Pacman = Pacman()
    plugins: list[Plugin] = field(default_factory=list)
    plugin_hooks: tuple[tuple[Plugin, Hook]] = tuple[tuple[Plugin, Hook]]()
    # dict for storing values that persist inside Frame
    dict: Dict | dict[str, Any] = dict[str, Any]()

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