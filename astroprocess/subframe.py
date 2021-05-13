from datetime import datetime
import json


import exifread


class Subframe:
    def __init__(self, subframe_path):
        self.path = subframe_path

        with open(subframe_path, "rb") as fdesc:
            tags = exifread.process_file(fdesc, details=False)

            print(tags.keys())
            self.exposure = int(str(tags["EXIF ExposureTime"]))
            self.iso = int(str(tags["EXIF ISOSpeedRatings"]))
            self.date_taken = datetime.strptime(str(tags["Image DateTime"]), "%Y:%m:%d %H:%M:%S")
            self.camera = str(tags["Image Model"]).replace(" ", "-")
