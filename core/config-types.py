
from typing import TypedDict

class Branding(TypedDict):
    name: str
    pretty_name: str
    safe_name: str

    bootloader_name: str
    boot_manager_name: str

    override_config: bool

class Users(TypedDict):
    wheel_user: str

    user_names: list[str]
    default_password: str

    passwords_directory: str

class Config(TypedDict):
    default_hostname: str

    branding: Branding
