#!/usr/bin/env python

# pylint: disable=missing-function-docstring,missing-module-docstring,missing-class-docstring,too-few-public-methods


import os
import re
from typing import Callable, List


NIKON_RAW_RE = re.compile(r".*\.nef$", re.I)
IMAGES_RE = re.compile(r".*\.(jpg|tif|fit)", re.I)
EDITS_RE = re.compile(r".*\.xcf", re.I)
TEXT_RE = re.compile(r".*\.txt", re.I)
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}", re.I)


IGNORE_LIST = [
        "__PlateSolve",
        "___example"
]


def ls_filter(path: str, filter_fn: Callable[[str], bool]) -> List[str]:
    if not os.path.exists(path):
        return []

    try:
        return [dir_entry.name
                for dir_entry in os.scandir(path)
                if filter_fn(dir_entry)]

    except FileNotFoundError:
        return []

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

class Session:
    @staticmethod
    def selector(dir_entry):
        return dir_entry.is_dir() and DATE_RE.match(dir_entry.name)

    def __init__(self, subject: str, session: str, root: str):
        self.subject = subject
        self.session = session
        self.path = os.path.join(root, session)

        self.lights = ls_filter(os.path.join(self.path, "Lights"),
                                lambda x: NIKON_RAW_RE.match(x.name) is not None)
        self.darks = ls_filter(os.path.join(self.path, "Darks"),
                               lambda x: NIKON_RAW_RE.match(x.name) is not None)
        self.flats = ls_filter(os.path.join(self.path, "Flats"),
                               lambda x: NIKON_RAW_RE.match(x.name) is not None)
        self.biases = ls_filter(os.path.join(self.path, "Biases"),
                                lambda x: NIKON_RAW_RE.match(x.name) is not None)

        self.stacks = ls_filter(os.path.join(self.path, "Stacks"),
                                lambda x: IMAGES_RE.match(x.name) is not None)
        self.edits = ls_filter(os.path.join(self.path, "Edits"),
                               lambda x: EDITS_RE.match(x.name) is not None)
        self.exports = ls_filter(os.path.join(self.path, "Edits"),
                                 lambda x: IMAGES_RE.match(x.name) is not None)


        try:
            self.notes = ls_filter(self.path, lambda x: TEXT_RE.match(x.name) is not None)
        except:
            print(self.path)
            raise ""


    def __str__(self, indent=""):
        return f"{indent}Session {self.session}: - " + \
               f"{len(self.lights)}# subs,\t{len(self.stacks)}# stacks,\t{len(self.exports)}# exports"



catalogue = Catalogue(name="Main", path="./")
print(catalogue)
