import logging
import subprocess

from core.config import get_dry_run

def subprocess_open(cmd: str, *args: str):
    subprocess_log = logging.getLogger(cmd)

    if get_dry_run():
        subprocess_log.info(f"Process '{cmd}' not opened because dry run is enabled (args: {args})")
        return

    subprocess_log.info(f"Opening process '{cmd}' with args: {args}")

    with subprocess.Popen(
        [cmd, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    ) as proc:
        if proc.stdout is not None:
            for line in proc.stdout:
                subprocess_log.info(line)

        _ = proc.wait(2000)

    if proc.returncode != 0:
        subprocess_log.error(f"Process '{cmd}' finished with errors (return code {proc.returncode})")
    else:
        subprocess_log.info(f"Process '{cmd}' finished (return code {proc.returncode})")