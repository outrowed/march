#!/usr/bin/python3
import logging

from core.frame import Frame
from core.loader import load_plugins

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)

frame = Frame()

load_plugins(frame, "./plugins")

frame.init_plugins()