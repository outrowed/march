
from core.frame import RunningFrame
from core.hook import Hooker
from core.plugin import Plugin

hooker = Hooker()

@hooker.hook("pre-install")
def pacstrap(frame: RunningFrame):
    print("do pacstrap stuff")
    frame.dispatch_hooks("install")

@hooker.hook("install")
def install_aur_helper(frame: RunningFrame):
    frame.dispatch_hooks("post-install")

@hooker.hook("post-install")
def install_large_packages(frame: RunningFrame):
    ...

def load_plugin() -> Plugin:
    return Plugin("example-plugin", hooker)