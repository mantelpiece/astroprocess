#!/usr/bin/env python

# pylint: disable=missing-function-docstring,missing-module-docstring,missing-class-docstring,too-few-public-methods


from datetime import datetime
import os
import re
from typing import Callable, List


NIKON_RAW_RE = re.compile(r".*\.nef$", re.I)
IMAGES_RE = re.compile(r".*\.(jpg|tif|fit)", re.I)
EDITS_RE = re.compile(r".*\.(xcf|fit|fits)", re.I)
TEXT_RE = re.compile(r".*\.txt", re.I)
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}", re.I)


IGNORE_LIST = [
        "__PlateSolve",
        "___example"
]

def scan_filter(path: str, filter_fn: Callable[[str], bool]) -> List[str]:
    if not os.path.exists(path):
        return []

    try:
        return [dir_entry
                for dir_entry in os.scandir(path)
                if filter_fn(dir_entry)]

    except FileNotFoundError:
        return []

def ls_filter(path: str, filter_fn: Callable[[str], bool]) -> List[str]:
    return [x.name for x in scan_filter(path, filter_fn)]


class Catalogue:
    @staticmethod
    def ignored_paths():
        return re.compile("_.*")

    def __init__(self, name: str, path: str):
        self.name = name
        self.path = path
        self.subjects = [
            Subject(name=subject, root=self.path)
            for subject
            in ls_filter(path, lambda x: x.is_dir() and not Catalogue.ignored_paths().match(x.name))
        ]

    def __str__(self):
        return f"Catalogue: {self.name} ({self.path})\n" + \
                "\n".join([subject.__str__("  ") for subject in self.subjects])

class Subject:
    def __init__(self, name: str, root: str):
        self.name = name
        self.path = os.path.join(root, name)

        self.sessions = [
            Session(subject=self.name, session=session, root=self.path)
            for session in ls_filter(self.path, lambda x: Session.selector(x))
        ]

    def __str__(self, indent=""):
        return f"{indent}Subject: {self.name}\n" + \
                "\n".join([session.__str__(f"  {indent}") for session in self.sessions])

class MultiSession:

    def __str__(self, index=""):
        return f"{indent}Multisession: stacks: {self.stacks}#,\t"



class Session:
    @staticmethod
    def selector(dir_entry):
        return dir_entry.is_dir() and DATE_RE.match(dir_entry.name)

    def sub_selector(self, sub_name, regex=NIKON_RAW_RE):
        path = os.path.join(self.path, sub_name)
        f = lambda x: regex.match(x.name) is not None

        return scan_filter(path, f)

    def __init__(self, subject: str, session: str, root: str):
        self.subject = subject
        self.session = session
        self.path = os.path.join(root, session)

        self.lights = self.sub_selector("LIGHT")
        self.darks = self.sub_selector("DARK")
        self.flats = self.sub_selector("FLAT")
        self.biases = self.sub_selector("BIAS")

        self.stacks = self.sub_selector("Stacks", IMAGES_RE)
        self.edits = self.sub_selector("Edits", EDITS_RE)
        self.exports = self.sub_selector("Exports", IMAGES_RE)


        try:
            self.notes = ls_filter(self.path, lambda x: TEXT_RE.match(x.name) is not None)
        except:
            print(self.path)
            raise ""

    def start_time(self):
        if not len(self.lights):
            return "-"

        start_ts = min([x.stat().st_ctime for x in self.lights], default=None)
        return datetime.fromtimestamp(start_ts).strftime("%H:%M:%S")

    def end_time(self):
        if not len(self.lights):
            return "-"

        start_ts = max([x.stat().st_ctime for x in self.lights], default=None)
        return datetime.fromtimestamp(start_ts).strftime("%H:%M:%S")

    def __str__(self, indent=""):
        return f"{indent}Session {self.session}: " + \
               f"{len(self.lights)}# subs,\t{len(self.stacks)}# stacks,\t{len(self.exports)}# exports,\t{self.start_time()},\t{self.end_time()}"



catalogue = Catalogue(name="Main", path="./")
print(catalogue)
