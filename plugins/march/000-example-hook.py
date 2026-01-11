import logging

from typing import TypedDict
from core.frame import Frame
from plugins.march import hooker

log = logging.getLogger(__name__)

@hooker.hook("init")
def init(frame: Frame):
    # print(frame)
    frame.dispatch_hook("pre-install")

@hooker.hook("pre-install")
def pacstrap(frame: Frame):
    log.info("do pacstrap stuff")
    frame.dispatch_hook("install")

@hooker.hook("install")
def install_aur_helper(frame: Frame):
    frame.dispatch_hook("post-install")

class Something(TypedDict):
    x: int
    y: int

@hooker.hook("post-install")
def install_large_packages(frame: Frame[Something]):
    frame.context_dict["x"] = 2