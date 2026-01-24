import logging

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any, cast

from core.pacman import Pacman
from core.hook import Hook
from core.plugin import Plugin

log = logging.getLogger(__name__)

@dataclass(kw_only=True)
class Frame:
    pacman: Pacman = field(default_factory=Pacman)
    plugins: list[Plugin] = field(default_factory=list)
    plugin_hooks: list[tuple[Plugin, Hook]] = field(default_factory=list)
    # dict for storing values that persist inside Frame
    context_dict: dict[str, dict[str, Any]] = field(default_factory=dict)
    
    def init_plugins(self):
        for plugin, hook in self.plugin_hooks:
            if hook.label == plugin.init_hook:
                log.info(f"init {plugin.name}:{hook.label}")
                hook.func(self)

    def get_context[Dict: Mapping[str, Any] = dict[str, Any]](
        self,
        context_name: str,
        *,
        context_type: type[Dict] | None = None
    ):
        _ = context_type # shuts up (based)pyright
        return cast(Dict, self.context_dict[context_name])

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