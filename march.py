#!/usr/bin/python3

from core.frame import Frame
from core.loader import load_plugins

frame = Frame()

load_plugins(frame, "./plugins")