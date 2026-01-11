
from core.frame import RunningFrame
from plugins.march import hooker

@hooker.hook("pre-install")
def pacstrap(frame: RunningFrame):
    print("do pacstrap stuff")
    frame.dispatch_hook("install")

@hooker.hook("install")
def install_aur_helper(frame: RunningFrame):
    frame.dispatch_hook("post-install")

@hooker.hook("post-install")
def install_large_packages(frame: RunningFrame):
    ...