import logging

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any

from core.pacman import Pacman
from core.hook import Hook
from core.plugin import Plugin

log = logging.getLogger(__name__)

@dataclass(kw_only=True)
class Frame[Dict: Mapping[str, Any] = Any]:
    pacman: Pacman = field(default_factory=Pacman)
    plugins: list[Plugin] = field(default_factory=list)
    plugin_hooks: tuple[tuple[Plugin, Hook]] = tuple[tuple[Plugin, Hook]]()
    # dict for storing values that persist inside Frame
    context_dict: Dict | dict[str, Any] = field(default_factory=dict[str, Any])

    def load_plugin_hooks(self):
        plugin_hooks: list[tuple[Plugin, Hook]] = []

        for plugin in self.plugins:
            for hook in plugin.hooker.generate_hooks():
                plugin_hooks.append((plugin, hook))

        self.plugin_hooks = tuple[tuple[Plugin, Hook]](plugin_hooks)
    
    def init_plugin_hooks(self):
        for plug, hook in self.plugin_hooks:
            if hook.label == plug.init_hook:
                hook.func(self)

    def dispatch_hook(self, label: str):
        for plugin, hook in self.plugin_hooks:
            if hook.label == label:
                log.debug(f"dispatch {plugin.name}:{hook.label}")
                hook.func(self)