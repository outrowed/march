import importlib, importlib.util
import logging
import tomllib

from os import PathLike
from pathlib import Path
from types import ModuleType
from typing import cast, Callable

from core.frame import Frame
from core.hook import Hook
from core.plugin import Plugin

type LoadPluginFunc = Callable[[], Plugin]

log = logging.getLogger(__name__)

def load_plugin_path(path: str | PathLike[str]):
    plugin_path = Path(path)
    plugin_init = plugin_path / "__init__.py"

    # prepare load_plugin function
    spec = importlib.util.spec_from_file_location(plugin_init.stem, plugin_init)

    if spec is None \
        or spec.loader is None: raise ModuleNotFoundError(path=str(plugin_init.resolve()))

    plugin_mod: ModuleType = importlib.util.module_from_spec(spec)

    spec.loader.exec_module(plugin_mod)

    if not hasattr(plugin_mod, "load_plugin"):
        raise AttributeError(name="load_plugin", obj=plugin_mod)
    
    load_plugin_func = cast(LoadPluginFunc, getattr(plugin_mod, "load_plugin"))

    # load hooks
    for file in plugin_path.glob("*.py"):
        if not file.is_file() \
            or file.stem == "__init__.py": continue

        spec = importlib.util.spec_from_file_location(file.stem, file)

        if spec is None \
            or spec.loader is None: raise ModuleNotFoundError(path=str(file.resolve()))

        hook_module = importlib.util.module_from_spec(spec)

        spec.loader.exec_module(hook_module)

    return load_plugin_func()

def load_plugins(frame: Frame, path: str | PathLike[str]):
    plugins_path = Path(path)
    plugin_loader_config_path = plugins_path / "plugin-loader.toml"

    plugin_loader_config = tomllib.loads(
        plugin_loader_config_path.read_text("utf-8")
    )
    load_order_names = tuple[str](plugin_loader_config["load_order"])
    
    loaded_plugins_map: dict[str, Plugin] = {}
    
    for plugin_path in plugins_path.iterdir():
        if plugin_path.is_file(): continue
        
        plugin = load_plugin_path(plugin_path)
        loaded_plugins_map[plugin.name] = plugin

    ordered_plugins: list[Plugin] = []

    for name in load_order_names:
        if name in loaded_plugins_map:
            ordered_plugins.append(loaded_plugins_map[name])
            del loaded_plugins_map[name]
        else:
            log.warning(f"plugin '{name}' in plugin-loader config is not found")

    remaining_plugins = sorted(loaded_plugins_map.values(), key=lambda p: p.name)
    ordered_plugins.extend(remaining_plugins)

    plugin_hooks: list[tuple[Plugin, Hook]] = []
    
    for plugin in ordered_plugins:
        for hook in plugin.hooker.generate_hooks():
            plugin_hooks.append((plugin, hook))

    frame.plugins.extend(ordered_plugins)
    frame.plugin_hooks.extend(plugin_hooks)