import os


from .subframe import Subframe


def register_directory(path: str):
    files = os.listdir(path)
    return [Subframe(os.path.join(path, f)) for f in files]
