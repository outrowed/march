import importlib, importlib.util

from os import PathLike
from pathlib import Path
from types import ModuleType
from typing import cast, Callable
from unittest import loader

from core.frame import Frame
from core.plugin import Plugin

type LoadPluginFunc = Callable[[], Plugin]

def load_plugin_path(frame: Frame, path: str | PathLike[str]):
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

    plugin = load_plugin_func()
    
    frame.plugins.append(plugin)

def load_plugins(frame: Frame, path: str | PathLike[str]):
    plugins_path = Path(path)

    for plugin in plugins_path.iterdir():
        if plugin.is_file(): continue

        load_plugin_path(frame, plugin)