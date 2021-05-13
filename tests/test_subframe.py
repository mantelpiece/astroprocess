import pytest
from datetime import datetime


from astroprocess.subframe import Subframe


class TestSubframe:

    @pytest.fixture
    def valid_nef(self):
        yield 'tests/resources/has-exposure/img.nef'

    def test_given_valid_frame_path_sets_exposure(self, valid_nef):
        subframe = Subframe(valid_nef)
        assert subframe.exposure == 60

    def test_given_valid_frame_path_sets_iso(self, valid_nef):
        subframe = Subframe(valid_nef)
        assert subframe.iso == 800

    def test_given_valid_frame_path_sets_date_taken(self, valid_nef):
        subframe = Subframe(valid_nef)
        assert subframe.date_taken == datetime(2021, 5, 12, 20, 53, 55)

    def test_given_valid_frame_path_sets_camera(self, valid_nef):
        subframe = Subframe(valid_nef)
        assert subframe.camera == "NIKON-D5600"
