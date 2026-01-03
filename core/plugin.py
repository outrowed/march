
import importlib, importlib.util

from dataclasses import dataclass
from os import PathLike
from pathlib import Path
from typing import Callable, cast

from core.frame import Frame
from core.hook import Hooker

type LoadPluginFunc = Callable[[], Plugin]

@dataclass
class Plugin:
    name: str
    hooker: Hooker

def load_plugins(path: str | PathLike[str], frame: Frame):
    plugin_path = Path(path)
    
    for file in plugin_path.glob("*.py"):
        if not file.is_file(): continue

        spec = importlib.util.spec_from_file_location(file.stem, file)

        if spec is None: raise ModuleNotFoundError(path=str(file.resolve()))

        module = importlib.util.module_from_spec(spec)

        if hasattr(module, "load_plugin"):
            mod_load_plugin = cast(LoadPluginFunc, getattr(module, "load_plugin"))
            plugin = mod_load_plugin()

            frame.plugins.append(plugin)
        else:
            raise AttributeError(name="load_plugin", obj=module)