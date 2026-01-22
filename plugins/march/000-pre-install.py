import logging

from core.config import get_config
from core.util import subprocess_open
from core.frame import Frame

from plugins.march import hooker

log = logging.getLogger(__name__)

@hooker.hook("pre-install")
def init(_frame: Frame):
    log.info("reflector")

    subprocess_open(
        "reflector",
        "--coutry", get_config("reflector-country"),
        "--latest", get_config("reflector-latest"),
        *"--protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist".split(" "),
        retry=True
    )

    #retry reflector --country "$IREFLECTOR_COUNTRY" --latest "$IREFLECTOR_LATEST" --protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist
