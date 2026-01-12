import logging

from core.frame import Frame
from plugins.march import hooker

log = logging.getLogger(__name__)

@hooker.hook("pre-install")
def init(_frame: Frame):
    log.info("reflector")

    #retry reflector --country "$IREFLECTOR_COUNTRY" --latest "$IREFLECTOR_LATEST" --protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist
