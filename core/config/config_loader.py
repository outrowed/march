
import logging
from os import environ, path
from pathlib import Path
from typing import Any
import tomli
import tomli_w

log = logging.getLogger(__name__)

CONFIG_DIRS = [
    environ.get("MARCH_CONFIG"),
    "%s/march" % environ.get("XDG_CONFIG_HOME"),
    "%s/.config/march" % environ.get("HOME")
]

def get_config_dir() -> Path:
    for dir in CONFIG_DIRS:
        if dir is not None and path.exists(dir):
            log.info("using config directory: %s", dir)
            return Path(dir)
    
    for dir in CONFIG_DIRS:
        if dir is not None:
            log.info("config directory doesn't exist, creating: %s", dir)

            pdir = Path(dir)
            pdir.mkdir(parents=True, exist_ok=True)

            return pdir

    raise FileNotFoundError()

cached_config: dict[str, Any] | None = None
cached_config_mtime: float | None = None

def get_cached_config() -> dict[str, Any]:
    global cached_config, cached_config_mtime

    main_config_file = get_config_dir() / "config.toml"

    main_config_file.touch()

    if cached_config_mtime == main_config_file.stat().st_mtime and cached_config is not None:
        return cached_config

    cached_config = tomli.loads(main_config_file.read_text("utf-8"))

    cached_config_mtime = main_config_file.stat().st_mtime

    return cached_config

def set_cached_config(obj: dict[str, Any]):
    global cached_config, cached_config_mtime

    main_config_file = get_config_dir() / "config.toml"

    main_config_file.touch()

    return main_config_file.write_text(tomli_w.dumps(obj), encoding="utf-8")
