#!/usr/bin/env python
"""Unit test suite for the fs_config_genertor.py tool."""

import tempfile
import textwrap
import unittest

from fs_config_generator import AID
from fs_config_generator import AIDHeaderParser
from fs_config_generator import FSConfigFileParser
from fs_config_generator import FSConfig
from fs_config_generator import Utils


# Disable protected access so we can test class internal
# methods. Also, disable invalid-name as some of the
# class method names are over length.
# pylint: disable=protected-access,invalid-name
class Tests(unittest.TestCase):
    """Test class for unit tests"""

    def test_is_overlap(self):
        """Test overlap detection helper"""

        self.assertTrue(AIDHeaderParser._is_overlap((0, 1), (1, 2)))

        self.assertTrue(AIDHeaderParser._is_overlap((0, 100), (90, 200)))

        self.assertTrue(AIDHeaderParser._is_overlap((20, 50), (1, 101)))

        self.assertFalse(AIDHeaderParser._is_overlap((0, 100), (101, 200)))

        self.assertFalse(AIDHeaderParser._is_overlap((-10, 0), (10, 20)))

    def test_in_any_range(self):
        """Test if value in range"""

        self.assertFalse(Utils.in_any_range(50, [(100, 200), (1, 2), (1, 1)]))
        self.assertFalse(Utils.in_any_range(250, [(100, 200), (1, 2), (1, 1)]))

        self.assertTrue(Utils.in_any_range(100, [(100, 200), (1, 2), (1, 1)]))
        self.assertTrue(Utils.in_any_range(200, [(100, 200), (1, 2), (1, 1)]))
        self.assertTrue(Utils.in_any_range(150, [(100, 200)]))

    def test_aid(self):
        """Test AID class constructor"""

        aid = AID('AID_FOO_BAR', '0xFF', 'myfakefile')
        self.assertEquals(aid.identifier, 'AID_FOO_BAR')
        self.assertEquals(aid.value, '0xFF')
        self.assertEquals(aid.found, 'myfakefile')
        self.assertEquals(aid.normalized_value, '255')
        self.assertEquals(aid.friendly, 'foo_bar')

        aid = AID('AID_MEDIA_EX', '1234', 'myfakefile')
        self.assertEquals(aid.identifier, 'AID_MEDIA_EX')
        self.assertEquals(aid.value, '1234')
        self.assertEquals(aid.found, 'myfakefile')
        self.assertEquals(aid.normalized_value, '1234')
        self.assertEquals(aid.friendly, 'mediaex')

    def test_aid_header_parser_good(self):
        """Test AID Header Parser good input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_FOO 1000
                #define AID_BAR 1001
                #define SOMETHING "something"
                #define AID_OEM_RESERVED_START 2900
                #define AID_OEM_RESERVED_END   2999
                #define AID_OEM_RESERVED_1_START  7000
                #define AID_OEM_RESERVED_1_END    8000
            """))
            temp_file.flush()

            parser = AIDHeaderParser(temp_file.name)
            oem_ranges = parser.oem_ranges
            aids = parser.aids

            self.assertTrue((2900, 2999) in oem_ranges)
            self.assertFalse((5000, 6000) in oem_ranges)

            for aid in aids:
                self.assertTrue(aid.normalized_value in ['1000', '1001'])
                self.assertFalse(aid.normalized_value in ['1', '2', '3'])

    def test_aid_header_parser_good_unordered(self):
        """Test AID Header Parser good unordered input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_FOO 1000
                #define AID_OEM_RESERVED_1_END    8000
                #define AID_BAR 1001
                #define SOMETHING "something"
                #define AID_OEM_RESERVED_END   2999
                #define AID_OEM_RESERVED_1_START  7000
                #define AID_OEM_RESERVED_START 2900
            """))
            temp_file.flush()

            parser = AIDHeaderParser(temp_file.name)
            oem_ranges = parser.oem_ranges
            aids = parser.aids

            self.assertTrue((2900, 2999) in oem_ranges)
            self.assertFalse((5000, 6000) in oem_ranges)

            for aid in aids:
                self.assertTrue(aid.normalized_value in ['1000', '1001'])
                self.assertFalse(aid.normalized_value in ['1', '2', '3'])

    def test_aid_header_parser_bad_aid(self):
        """Test AID Header Parser bad aid input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_FOO "bad"
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_bad_oem_range(self):
        """Test AID Header Parser bad oem range input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_OEM_RESERVED_START 2900
                #define AID_OEM_RESERVED_END   1800
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_bad_oem_range_no_end(self):
        """Test AID Header Parser bad oem range (no end) input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_OEM_RESERVED_START 2900
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_bad_oem_range_no_start(self):
        """Test AID Header Parser bad oem range (no start) input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_OEM_RESERVED_END 2900
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_bad_oem_range_mismatch_start_end(self):
        """Test AID Header Parser bad oem range mismatched input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_OEM_RESERVED_START 2900
                #define AID_OEM_RESERVED_2_END 2900
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_bad_duplicate_ranges(self):
        """Test AID Header Parser exits cleanly on duplicate AIDs"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_FOO 100
                #define AID_BAR 100
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                AIDHeaderParser(temp_file.name)

    def test_aid_header_parser_no_bad_aids(self):
        """Test AID Header Parser that it doesn't contain:
        Ranges, ie things the end with "_START" or "_END"
        AID_APP
        AID_USER
        For more details see:
          - https://android-review.googlesource.com/#/c/313024
          - https://android-review.googlesource.com/#/c/313169
        """

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                #define AID_APP              10000 /* TODO: switch users over to AID_APP_START */
                #define AID_APP_START        10000 /* first app user */
                #define AID_APP_END          19999 /* last app user */

                #define AID_CACHE_GID_START  20000 /* start of gids for apps to mark cached data */
                #define AID_CACHE_GID_END    29999 /* end of gids for apps to mark cached data */

                #define AID_SHARED_GID_START 50000 /* start of gids for apps in each user to share */
                #define AID_SHARED_GID_END   59999 /* end of gids for apps in each user to share */

                #define AID_ISOLATED_START   99000 /* start of uids for fully isolated sandboxed processes */
                #define AID_ISOLATED_END     99999 /* end of uids for fully isolated sandboxed processes */

                #define AID_USER            100000 /* TODO: switch users over to AID_USER_OFFSET */
                #define AID_USER_OFFSET     100000 /* offset for uid ranges for each user */
            """))
            temp_file.flush()

            parser = AIDHeaderParser(temp_file.name)
            aids = parser.aids

            bad_aids = ['_START', '_END', 'AID_APP', 'AID_USER']

            for aid in aids:
                self.assertFalse(
                    any(bad in aid.identifier for bad in bad_aids),
                    'Not expecting keywords "%s" in aids "%s"' %
                    (str(bad_aids), str([tmp.identifier for tmp in aids])))

    def test_fs_config_file_parser_good(self):
        """Test FSConfig Parser good input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                [/system/bin/file]
                user: AID_FOO
                group: AID_SYSTEM
                mode: 0777
                caps: BLOCK_SUSPEND

                [/vendor/path/dir/]
                user: AID_FOO
                group: AID_SYSTEM
                mode: 0777
                caps: 0

                [AID_OEM1]
                # 5001 in base16
                value: 0x1389
            """))
            temp_file.flush()

            parser = FSConfigFileParser([temp_file.name], [(5000, 5999)])
            files = parser.files
            dirs = parser.dirs
            aids = parser.aids

            self.assertEquals(len(files), 1)
            self.assertEquals(len(dirs), 1)
            self.assertEquals(len(aids), 1)

            aid = aids[0]
            fcap = files[0]
            dcap = dirs[0]

            self.assertEqual(fcap,
                             FSConfig('0777', 'AID_FOO', 'AID_SYSTEM',
                                      '(1ULL << CAP_BLOCK_SUSPEND)',
                                      '/system/bin/file', temp_file.name))

            self.assertEqual(dcap,
                             FSConfig('0777', 'AID_FOO', 'AID_SYSTEM', '(0)',
                                      '/vendor/path/dir/', temp_file.name))

            self.assertEqual(aid, AID('AID_OEM1', '0x1389', temp_file.name))

    def test_fs_config_file_parser_bad(self):
        """Test FSConfig Parser bad input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                [/system/bin/file]
                caps: BLOCK_SUSPEND
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                FSConfigFileParser([temp_file.name], [(5000, 5999)])

    def test_fs_config_file_parser_bad_aid_range(self):
        """Test FSConfig Parser bad aid range value input file"""

        with tempfile.NamedTemporaryFile() as temp_file:
            temp_file.write(
                textwrap.dedent("""
                [AID_OEM1]
                value: 25
            """))
            temp_file.flush()

            with self.assertRaises(SystemExit):
                FSConfigFileParser([temp_file.name], [(5000, 5999)])
