
def get_dry_run() -> bool:
    return True

def get_pacman_output() -> bool:
    return True

def get_config[T](_key: str) -> T:
    raise NotImplementedError()