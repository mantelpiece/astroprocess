import os
import re
from dataclasses import dataclass
from typing import Optional


IMG_FILENAME_REGEX=r"[^.]+\.nef"

class SubframeGroup:
    directory: str
    camera: str
    count: int
    exposure: int
    iso: Optional[int]
    # gain: Optional[int]
    # offset: Optional[int]

    def __init__(self, directory):
        self.directory = directory

        files = os.listdir(directory)
        self.count = len([f for f in files if re.match(IMG_FILENAME_REGEX, f)])


