#!env python

import os
import re
import sys


class Sub:
    path = None
    name = None
    subtype = None
    exposure = None
    iso = None
    hfr = None
    date = None
    time = None

    def __init__(self, name, subtype, exposure, iso, hfr):
        self.name = name
        self.subtype = subtype
        self.exposure = exposure
        self.iso = iso
        self.hfr = hfr


    def __str__(self):
        return f"{self.name}\t{self.subtype}\t{self.exposure}\t{self.iso}\t{self.hfr}"


NAME_REGEX = r"([A-Za-z]+)_(\d{4,4})_(\d+\.\d+)_(\d+)_(\d+\.\d+)?.nef"
def parse_filename(filename):
    match = re.match(NAME_REGEX, filename)
    if match:
        (subtype, index, exposure, iso, hfr) = match.groups()
        return Sub(match.group(0), subtype, exposure, iso, hfr)
    else:
        return None


def main(path):
    filenames = os.listdir(path)


    subs = [sub for sub in [parse_filename(fn) for fn in filenames] if sub is not None]
    [print(f"{sub}") for sub in subs]

        #  print("subtype: ", subtype)
        #  print("index: ", index)
        #  print("exposure: ", exposure)
        #  print("iso: ", iso)
        #  print("hfr: ", hfr)


if __name__ == "__main__":
    main(sys.argv[1])
