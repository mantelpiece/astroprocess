from astroprocess.subframe_group import SubframeGroup


class TestSubframeGroup:

    def test_given_a_directory_populates_a_count(self):
        sfg = SubframeGroup('tests/resources/clean')
        assert sfg.count == 2

    def test_given_a_directory_includes_files_matching_filename_regex(self):
        sfg = SubframeGroup('tests/resources/extra-file')
        assert sfg.count == 2
