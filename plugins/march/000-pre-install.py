import logging

from core.config import get_config
from core.util import subprocess_open
from core.frame import Frame
from core.pacman import Pacman

from plugins.march import hooker

log = logging.getLogger(__name__)

pacman = Pacman()

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

    pacman.pacstrap(
        "/mnt",
        get_config("pacstrap")
    )

    #retry reflector --country "$IREFLECTOR_COUNTRY" --latest "$IREFLECTOR_LATEST" --protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist
