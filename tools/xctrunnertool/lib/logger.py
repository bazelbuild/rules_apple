#!/usr/bin/env python3

import logging
import os
import sys


class StreamToLogger(object):
    """
    Fake file-like stream object that redirects writes to a logger instance.
    """

    def __init__(self, logger, level):
        self.logger = logger
        self.level = level
        self.linebuf = ""

    def write(self, buf):
        "Writes to file"
        for line in buf.rstrip().splitlines():
            self.logger.log(self.level, line.rstrip())

    def flush(self):
        "Flushes IO buffer"
        pass


class Logger:
    "Logger class."

    def __init__(self, filename: str, level: str = "INFO"):
        logging.basicConfig(
            format="%(asctime)s MakeXCTRunner %(levelname)-8s %(message)s",
            level=level,
            datefmt="%Y-%m-%d %H:%M:%S %z",
            filename=filename,
        )

        # Add console logger in addition to a file logger
        console = logging.StreamHandler()
        lvl = (os.environ.get("CONSOLE_LOG_LEVEL") or "info").upper()
        console.setLevel(lvl)
        formatter = logging.Formatter(
            "%(asctime)s MakeXCTRunner %(levelname)-8s %(message)s"
        )
        console.setFormatter(formatter)
        logging.getLogger("").addHandler(console)

    def get(self, name: str) -> logging.Logger:
        "Returns logger with the given name."
        log = logging.getLogger(name)
        sys.stderr = StreamToLogger(log, logging.ERROR)
        return log
