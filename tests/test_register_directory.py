import pytest


from astroprocess.register_directory import register_directory

class TestRegisterDirectory:
    @pytest.fixture
    def clean_dir(self):
        return 'tests/resources/clean/'


    def test_given_directory_returns_subframe_group(self, clean_dir):
        foo = register_directory(clean_dir)

        assert len(foo) == 2
