
from core.hook import Hooker
from core.plugin import Plugin

hooker = Hooker()

def load_plugin() -> Plugin:
    return Plugin(
        name="example-plugin",
        init_hook="init",
        hooker=hooker
    )