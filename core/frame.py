import logging

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any

from core.pacman import Pacman
from core.hook import Hook
from core.plugin import Plugin

log = logging.getLogger(__name__)

@dataclass(kw_only=True)
class Frame[ContextDict: Mapping[str, Any] = Any]:
    pacman: Pacman = field(default_factory=Pacman)
    plugins: list[Plugin] = field(default_factory=list)
    plugin_hooks: tuple[tuple[Plugin, Hook]] = tuple[tuple[Plugin, Hook]]()
    # dict for storing values that persist inside Frame
    context_dict: ContextDict | dict[str, Any] = field(default_factory=dict[str, Any])

    def load_plugin_hooks(self):
        plugin_hooks: list[tuple[Plugin, Hook]] = []

        for plugin in self.plugins:
            for hook in plugin.hooker.generate_hooks():
                plugin_hooks.append((plugin, hook))

        self.plugin_hooks = tuple[tuple[Plugin, Hook]](plugin_hooks)
    
    def init_plugin_hooks(self):
        for plugin, hook in self.plugin_hooks:
            if hook.label == plugin.init_hook:
                log.info(f"init {plugin.name}:{hook.label}")
                hook.func(self)

    def dispatch_hook(self, label: str):
        hook_label = label
        target_plugin_name: str | None = None

        # plugin-specific hook
        if ":" in label:
            target_plugin_name, hook_label = label.split(":")

        for plugin, hook in self.plugin_hooks:
            if hook.label == hook_label:
                if target_plugin_name is not None \
                    and plugin.name != target_plugin_name: continue

                log.info(f"dispatch {plugin.name}:{hook.label}")
                hook.func(self)