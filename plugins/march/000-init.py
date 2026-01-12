import logging

from core.frame import Frame
from plugins.march import hooker

log = logging.getLogger(__name__)

@hooker.hook("init")
def init(frame: Frame):
    frame.dispatch_hook("pre-install")
