import logging
import os
import subprocess

from typing import Any

from core.config import get_dry_run

def subprocess_open(cmd: str, *args: str, retry: bool = False):
    proc_logger = logging.getLogger(cmd)

    if get_dry_run():
        proc_logger.info(f"Process '{cmd}' not opened because dry run is enabled (args: {args})")
        return

    proc_logger.info(f"Opening process '{cmd}' with args: {args}")

    with subprocess.Popen(
        [cmd, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    ) as proc:
        if proc.stdout is not None:
            for line in proc.stdout:
                proc_logger.info(line)

        _ = proc.wait(5000)

    if proc.returncode != 0:
        proc_logger.error(f"Process '{cmd}' finished with errors (return code {proc.returncode})")
        if retry: subprocess_retry(proc_logger, cmd, *args)
    else:
        proc_logger.info(f"Process '{cmd}' finished (return code {proc.returncode})")


def subprocess_retry(logger: logging.Logger, *subprocess_args: Any):
    while True:
        logger.info("Prompt user for subprocess retry")
        user_retry = input("Would you like to retry or go to shell? [yns]").lower()

        if user_retry == "y":
            logger.info("Doing subprocess retry")
            subprocess_open(*subprocess_args, retry=True)
        elif user_retry == "n":
            logger.info("Declined subprocess retry")
        elif user_retry == "s":
            logger.info("Opening user shell in subprocess retry")
            print("Opening user shell, you can fix the problems here")
            shell = os.environ.get("SHELL", "/bin/sh")

            _ = subprocess.run([shell, "-l"], check=False)
            continue
        else:
            print("Invalid option")
            continue

        break