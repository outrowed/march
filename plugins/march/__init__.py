
from core.hook import Hooker
from core.plugin import Plugin

hooker = Hooker()

def load_plugin() -> Plugin:
    print(hooker.funcs)

    return Plugin("march", hooker)