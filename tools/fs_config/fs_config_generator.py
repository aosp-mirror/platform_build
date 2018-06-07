#!/usr/bin/env python
"""Generates config files for Android file system properties.

This script is used for generating configuration files for configuring
Android filesystem properties. Internally, its composed of a plug-able
interface to support the understanding of new input and output parameters.

Run the help for a list of supported plugins and their capabilities.

Further documentation can be found in the README.
"""

import argparse
import ConfigParser
import re
import sys
import textwrap

# Keep the tool in one file to make it easy to run.
# pylint: disable=too-many-lines


# Lowercase generator used to be inline with @staticmethod.
class generator(object):  # pylint: disable=invalid-name
    """A decorator class to add commandlet plugins.

    Used as a decorator to classes to add them to
    the internal plugin interface. Plugins added
    with @generator() are automatically added to
    the command line.

    For instance, to add a new generator
    called foo and have it added just do this:

        @generator("foo")
        class FooGen(object):
            ...
    """
    _generators = {}

    def __init__(self, gen):
        """
        Args:
            gen (str): The name of the generator to add.

        Raises:
            ValueError: If there is a similarly named generator already added.

        """
        self._gen = gen

        if gen in generator._generators:
            raise ValueError('Duplicate generator name: ' + gen)

        generator._generators[gen] = None

    def __call__(self, cls):

        generator._generators[self._gen] = cls()
        return cls

    @staticmethod
    def get():
        """Gets the list of generators.

        Returns:
           The list of registered generators.
        """
        return generator._generators


class Utils(object):
    """Various assorted static utilities."""

    @staticmethod
    def in_any_range(value, ranges):
        """Tests if a value is in a list of given closed range tuples.

        A range tuple is a closed range. That means it's inclusive of its
        start and ending values.

        Args:
            value (int): The value to test.
            range [(int, int)]: The closed range list to test value within.

        Returns:
            True if value is within the closed range, false otherwise.
        """

        return any(lower <= value <= upper for (lower, upper) in ranges)

    @staticmethod
    def get_login_and_uid_cleansed(aid):
        """Returns a passwd/group file safe logon and uid.

        This checks that the logon and uid of the AID do not
        contain the delimiter ":" for a passwd/group file.

        Args:
            aid (AID): The aid to check

        Returns:
            logon, uid of the AID after checking its safe.

        Raises:
            ValueError: If there is a delimiter charcter found.
        """
        logon = aid.friendly
        uid = aid.normalized_value
        if ':' in uid:
            raise ValueError(
                'Cannot specify delimiter character ":" in uid: "%s"' % uid)
        if ':' in logon:
            raise ValueError(
                'Cannot specify delimiter character ":" in logon: "%s"' % logon)
        return logon, uid


class AID(object):
    """This class represents an Android ID or an AID.

    Attributes:
        identifier (str): The identifier name for a #define.
        value (str) The User Id (uid) of the associate define.
        found (str) The file it was found in, can be None.
        normalized_value (str): Same as value, but base 10.
        friendly (str): The friendly name of aid.
    """

    PREFIX = 'AID_'

    # Some of the AIDS like AID_MEDIA_EX had names like mediaex
    # list a map of things to fixup until we can correct these
    # at a later date.
    _FIXUPS = {
        'media_drm': 'mediadrm',
        'media_ex': 'mediaex',
        'media_codec': 'mediacodec'
    }

    def __init__(self, identifier, value, found):
        """
        Args:
            identifier: The identifier name for a #define <identifier>.
            value: The value of the AID, aka the uid.
            found (str): The file found in, not required to be specified.

        Raises:
            ValueError: if the friendly name is longer than 31 characters as
                that is bionic's internal buffer size for name.
            ValueError: if value is not a valid string number as processed by
                int(x, 0)
        """
        self.identifier = identifier
        self.value = value
        self.found = found
        try:
            self.normalized_value = str(int(value, 0))
        except ValueException:
            raise ValueError('Invalid "value", not aid number, got: \"%s\"' % value)

        # Where we calculate the friendly name
        friendly = identifier[len(AID.PREFIX):].lower()
        self.friendly = AID._fixup_friendly(friendly)

        if len(self.friendly) > 31:
            raise ValueError('AID names must be under 32 characters "%s"' % self.friendly)


    def __eq__(self, other):

        return self.identifier == other.identifier \
            and self.value == other.value and self.found == other.found \
            and self.normalized_value == other.normalized_value

    @staticmethod
    def is_friendly(name):
        """Determines if an AID is a freindly name or C define.

        For example if name is AID_SYSTEM it returns false, if name
        was system, it would return true.

        Returns:
            True if name is a friendly name False otherwise.
        """

        return not name.startswith(AID.PREFIX)

    @staticmethod
    def _fixup_friendly(friendly):
        """Fixup friendly names that historically don't follow the convention.

        Args:
            friendly (str): The friendly name.

        Returns:
            The fixedup friendly name as a str.
        """

        if friendly in AID._FIXUPS:
            return AID._FIXUPS[friendly]

        return friendly


class FSConfig(object):
    """Represents a filesystem config array entry.

    Represents a file system configuration entry for specifying
    file system capabilities.

    Attributes:
        mode (str): The mode of the file or directory.
        user (str): The uid or #define identifier (AID_SYSTEM)
        group (str): The gid or #define identifier (AID_SYSTEM)
        caps (str): The capability set.
        filename (str): The file it was found in.
    """

    def __init__(self, mode, user, group, caps, path, filename):
        """
        Args:
            mode (str): The mode of the file or directory.
            user (str): The uid or #define identifier (AID_SYSTEM)
            group (str): The gid or #define identifier (AID_SYSTEM)
            caps (str): The capability set as a list.
            filename (str): The file it was found in.
        """
        self.mode = mode
        self.user = user
        self.group = group
        self.caps = caps
        self.path = path
        self.filename = filename

    def __eq__(self, other):

        return self.mode == other.mode and self.user == other.user \
            and self.group == other.group and self.caps == other.caps \
            and self.path == other.path and self.filename == other.filename


class AIDHeaderParser(object):
    """Parses an android_filesystem_config.h file.

    Parses a C header file and extracts lines starting with #define AID_<name>
    while capturing the OEM defined ranges and ignoring other ranges. It also
    skips some hardcoded AIDs it doesn't need to generate a mapping for.
    It provides some basic sanity checks. The information extracted from this
    file can later be used to sanity check other things (like oem ranges) as
    well as generating a mapping of names to uids. It was primarily designed to
    parse the private/android_filesystem_config.h, but any C header should
    work.
    """


    _SKIP_AIDS = [
        re.compile(r'%sUNUSED[0-9].*' % AID.PREFIX),
        re.compile(r'%sAPP' % AID.PREFIX), re.compile(r'%sUSER' % AID.PREFIX)
    ]
    _AID_DEFINE = re.compile(r'\s*#define\s+%s.*' % AID.PREFIX)
    _OEM_START_KW = 'START'
    _OEM_END_KW = 'END'
    _OEM_RANGE = re.compile('%sOEM_RESERVED_[0-9]*_{0,1}(%s|%s)' %
                            (AID.PREFIX, _OEM_START_KW, _OEM_END_KW))
    # AID lines cannot end with _START or _END, ie AID_FOO is OK
    # but AID_FOO_START is skiped. Note that AID_FOOSTART is NOT skipped.
    _AID_SKIP_RANGE = ['_' + _OEM_START_KW, '_' + _OEM_END_KW]
    _COLLISION_OK = ['AID_APP', 'AID_APP_START', 'AID_USER', 'AID_USER_OFFSET']

    def __init__(self, aid_header):
        """
        Args:
            aid_header (str): file name for the header
                file containing AID entries.
        """
        self._aid_header = aid_header
        self._aid_name_to_value = {}
        self._aid_value_to_name = {}
        self._oem_ranges = {}

        with open(aid_header) as open_file:
            self._parse(open_file)

        try:
            self._process_and_check()
        except ValueError as exception:
            sys.exit('Error processing parsed data: "%s"' % (str(exception)))

    def _parse(self, aid_file):
        """Parses an AID header file. Internal use only.

        Args:
            aid_file (file): The open AID header file to parse.
        """

        for lineno, line in enumerate(aid_file):

            def error_message(msg):
                """Creates an error message with the current parsing state."""
                # pylint: disable=cell-var-from-loop
                return 'Error "{}" in file: "{}" on line: {}'.format(
                    msg, self._aid_header, str(lineno))

            if AIDHeaderParser._AID_DEFINE.match(line):
                chunks = line.split()
                identifier = chunks[1]
                value = chunks[2]

                if any(x.match(identifier) for x in AIDHeaderParser._SKIP_AIDS):
                    continue

                try:
                    if AIDHeaderParser._is_oem_range(identifier):
                        self._handle_oem_range(identifier, value)
                    elif not any(
                            identifier.endswith(x)
                            for x in AIDHeaderParser._AID_SKIP_RANGE):
                        self._handle_aid(identifier, value)
                except ValueError as exception:
                    sys.exit(
                        error_message('{} for "{}"'.format(exception,
                                                           identifier)))

    def _handle_aid(self, identifier, value):
        """Handle an AID C #define.

        Handles an AID, sanity checking, generating the friendly name and
        adding it to the internal maps. Internal use only.

        Args:
            identifier (str): The name of the #define identifier. ie AID_FOO.
            value (str): The value associated with the identifier.

        Raises:
            ValueError: With message set to indicate the error.
        """

        aid = AID(identifier, value, self._aid_header)

        # duplicate name
        if aid.friendly in self._aid_name_to_value:
            raise ValueError('Duplicate aid "%s"' % identifier)

        if value in self._aid_value_to_name and aid.identifier not in AIDHeaderParser._COLLISION_OK:
            raise ValueError('Duplicate aid value "%s" for %s' % (value,
                                                                  identifier))

        self._aid_name_to_value[aid.friendly] = aid
        self._aid_value_to_name[value] = aid.friendly

    def _handle_oem_range(self, identifier, value):
        """Handle an OEM range C #define.

        When encountering special AID defines, notably for the OEM ranges
        this method handles sanity checking and adding them to the internal
        maps. For internal use only.

        Args:
            identifier (str): The name of the #define identifier.
                ie AID_OEM_RESERVED_START/END.
            value (str): The value associated with the identifier.

        Raises:
            ValueError: With message set to indicate the error.
        """

        try:
            int_value = int(value, 0)
        except ValueError:
            raise ValueError(
                'Could not convert "%s" to integer value, got: "%s"' %
                (identifier, value))

        # convert AID_OEM_RESERVED_START or AID_OEM_RESERVED_<num>_START
        # to AID_OEM_RESERVED or AID_OEM_RESERVED_<num>
        is_start = identifier.endswith(AIDHeaderParser._OEM_START_KW)

        if is_start:
            tostrip = len(AIDHeaderParser._OEM_START_KW)
        else:
            tostrip = len(AIDHeaderParser._OEM_END_KW)

        # ending _
        tostrip = tostrip + 1

        strip = identifier[:-tostrip]
        if strip not in self._oem_ranges:
            self._oem_ranges[strip] = []

        if len(self._oem_ranges[strip]) > 2:
            raise ValueError('Too many same OEM Ranges "%s"' % identifier)

        if len(self._oem_ranges[strip]) == 1:
            tmp = self._oem_ranges[strip][0]

            if tmp == int_value:
                raise ValueError('START and END values equal %u' % int_value)
            elif is_start and tmp < int_value:
                raise ValueError('END value %u less than START value %u' %
                                 (tmp, int_value))
            elif not is_start and tmp > int_value:
                raise ValueError('END value %u less than START value %u' %
                                 (int_value, tmp))

        # Add START values to the head of the list and END values at the end.
        # Thus, the list is ordered with index 0 as START and index 1 as END.
        if is_start:
            self._oem_ranges[strip].insert(0, int_value)
        else:
            self._oem_ranges[strip].append(int_value)

    def _process_and_check(self):
        """Process, check and populate internal data structures.

        After parsing and generating the internal data structures, this method
        is responsible for sanity checking ALL of the acquired data.

        Raises:
            ValueError: With the message set to indicate the specific error.
        """

        # tuplefy the lists since range() does not like them mutable.
        self._oem_ranges = [
            AIDHeaderParser._convert_lst_to_tup(k, v)
            for k, v in self._oem_ranges.iteritems()
        ]

        # Check for overlapping ranges
        for i, range1 in enumerate(self._oem_ranges):
            for range2 in self._oem_ranges[i + 1:]:
                if AIDHeaderParser._is_overlap(range1, range2):
                    raise ValueError("Overlapping OEM Ranges found %s and %s" %
                                     (str(range1), str(range2)))

        # No core AIDs should be within any oem range.
        for aid in self._aid_value_to_name:

            if Utils.in_any_range(aid, self._oem_ranges):
                name = self._aid_value_to_name[aid]
                raise ValueError(
                    'AID "%s" value: %u within reserved OEM Range: "%s"' %
                    (name, aid, str(self._oem_ranges)))

    @property
    def oem_ranges(self):
        """Retrieves the OEM closed ranges as a list of tuples.

        Returns:
            A list of closed range tuples: [ (0, 42), (50, 105) ... ]
        """
        return self._oem_ranges

    @property
    def aids(self):
        """Retrieves the list of found AIDs.

        Returns:
            A list of AID() objects.
        """
        return self._aid_name_to_value.values()

    @staticmethod
    def _convert_lst_to_tup(name, lst):
        """Converts a mutable list to a non-mutable tuple.

        Used ONLY for ranges and thus enforces a length of 2.

        Args:
            lst (List): list that should be "tuplefied".

        Raises:
            ValueError if lst is not a list or len is not 2.

        Returns:
            Tuple(lst)
        """
        if not lst or len(lst) != 2:
            raise ValueError('Mismatched range for "%s"' % name)

        return tuple(lst)

    @staticmethod
    def _is_oem_range(aid):
        """Detects if a given aid is within the reserved OEM range.

        Args:
            aid (int): The aid to test

        Returns:
            True if it is within the range, False otherwise.
        """

        return AIDHeaderParser._OEM_RANGE.match(aid)

    @staticmethod
    def _is_overlap(range_a, range_b):
        """Calculates the overlap of two range tuples.

        A range tuple is a closed range. A closed range includes its endpoints.
        Note that python tuples use () notation which collides with the
        mathematical notation for open ranges.

        Args:
            range_a: The first tuple closed range eg (0, 5).
            range_b: The second tuple closed range eg (3, 7).

        Returns:
            True if they overlap, False otherwise.
        """

        return max(range_a[0], range_b[0]) <= min(range_a[1], range_b[1])


class FSConfigFileParser(object):
    """Parses a config.fs ini format file.

    This class is responsible for parsing the config.fs ini format files.
    It collects and checks all the data in these files and makes it available
    for consumption post processed.
    """

    # These _AID vars work together to ensure that an AID section name
    # cannot contain invalid characters for a C define or a passwd/group file.
    # Since _AID_PREFIX is within the set of _AID_MATCH the error logic only
    # checks end, if you change this, you may have to update the error
    # detection code.
    _AID_MATCH = re.compile('%s[A-Z0-9_]+' % AID.PREFIX)
    _AID_ERR_MSG = 'Expecting upper case, a number or underscore'

    # list of handler to required options, used to identify the
    # parsing section
    _SECTIONS = [('_handle_aid', ('value',)),
                 ('_handle_path', ('mode', 'user', 'group', 'caps'))]

    def __init__(self, config_files, oem_ranges):
        """
        Args:
            config_files ([str]): The list of config.fs files to parse.
                Note the filename is not important.
            oem_ranges ([(),()]): range tuples indicating reserved OEM ranges.
        """

        self._files = []
        self._dirs = []
        self._aids = []

        self._seen_paths = {}
        # (name to file, value to aid)
        self._seen_aids = ({}, {})

        self._oem_ranges = oem_ranges

        self._config_files = config_files

        for config_file in self._config_files:
            self._parse(config_file)

    def _parse(self, file_name):
        """Parses and verifies config.fs files. Internal use only.

        Args:
            file_name (str): The config.fs (PythonConfigParser file format)
                file to parse.

        Raises:
            Anything raised by ConfigParser.read()
        """

        # Separate config parsers for each file found. If you use
        # read(filenames...) later files can override earlier files which is
        # not what we want. Track state across files and enforce with
        # _handle_dup(). Note, strict ConfigParser is set to true in
        # Python >= 3.2, so in previous versions same file sections can
        # override previous
        # sections.

        config = ConfigParser.ConfigParser()
        config.read(file_name)

        for section in config.sections():

            found = False

            for test in FSConfigFileParser._SECTIONS:
                handler = test[0]
                options = test[1]

                if all([config.has_option(section, item) for item in options]):
                    handler = getattr(self, handler)
                    handler(file_name, section, config)
                    found = True
                    break

            if not found:
                sys.exit('Invalid section "%s" in file: "%s"' %
                         (section, file_name))

            # sort entries:
            # * specified path before prefix match
            # ** ie foo before f*
            # * lexicographical less than before other
            # ** ie boo before foo
            # Given these paths:
            # paths=['ac', 'a', 'acd', 'an', 'a*', 'aa', 'ac*']
            # The sort order would be:
            # paths=['a', 'aa', 'ac', 'acd', 'an', 'ac*', 'a*']
            # Thus the fs_config tools will match on specified paths before
            # attempting prefix, and match on the longest matching prefix.
            self._files.sort(key=FSConfigFileParser._file_key)

            # sort on value of (file_name, name, value, strvalue)
            # This is only cosmetic so AIDS are arranged in ascending order
            # within the generated file.
            self._aids.sort(key=lambda item: item.normalized_value)

    def _handle_aid(self, file_name, section_name, config):
        """Verifies an AID entry and adds it to the aid list.

        Calls sys.exit() with a descriptive message of the failure.

        Args:
            file_name (str): The filename of the config file being parsed.
            section_name (str): The section name currently being parsed.
            config (ConfigParser): The ConfigParser section being parsed that
                the option values will come from.
        """

        def error_message(msg):
            """Creates an error message with current parsing state."""
            return '{} for: "{}" file: "{}"'.format(msg, section_name,
                                                    file_name)

        FSConfigFileParser._handle_dup_and_add('AID', file_name, section_name,
                                               self._seen_aids[0])

        match = FSConfigFileParser._AID_MATCH.match(section_name)
        invalid = match.end() if match else len(AID.PREFIX)
        if invalid != len(section_name):
            tmp_errmsg = ('Invalid characters in AID section at "%d" for: "%s"'
                          % (invalid, FSConfigFileParser._AID_ERR_MSG))
            sys.exit(error_message(tmp_errmsg))

        value = config.get(section_name, 'value')

        if not value:
            sys.exit(error_message('Found specified but unset "value"'))

        try:
            aid = AID(section_name, value, file_name)
        except ValueError as exception:
            sys.exit(error_message(exception))

        # Values must be within OEM range
        if not Utils.in_any_range(int(aid.value, 0), self._oem_ranges):
            emsg = '"value" not in valid range %s, got: %s'
            emsg = emsg % (str(self._oem_ranges), value)
            sys.exit(error_message(emsg))

        # use the normalized int value in the dict and detect
        # duplicate definitions of the same value
        FSConfigFileParser._handle_dup_and_add(
            'AID', file_name, aid.normalized_value, self._seen_aids[1])

        # Append aid tuple of (AID_*, base10(value), _path(value))
        # We keep the _path version of value so we can print that out in the
        # generated header so investigating parties can identify parts.
        # We store the base10 value for sorting, so everything is ascending
        # later.
        self._aids.append(aid)

    def _handle_path(self, file_name, section_name, config):
        """Add a file capability entry to the internal list.

        Handles a file capability entry, verifies it, and adds it to
        to the internal dirs or files list based on path. If it ends
        with a / its a dir. Internal use only.

        Calls sys.exit() on any validation error with message set.

        Args:
            file_name (str): The current name of the file being parsed.
            section_name (str): The name of the section to parse.
            config (str): The config parser.
        """

        FSConfigFileParser._handle_dup_and_add('path', file_name, section_name,
                                               self._seen_paths)

        mode = config.get(section_name, 'mode')
        user = config.get(section_name, 'user')
        group = config.get(section_name, 'group')
        caps = config.get(section_name, 'caps')

        errmsg = ('Found specified but unset option: \"%s" in file: \"' +
                  file_name + '\"')

        if not mode:
            sys.exit(errmsg % 'mode')

        if not user:
            sys.exit(errmsg % 'user')

        if not group:
            sys.exit(errmsg % 'group')

        if not caps:
            sys.exit(errmsg % 'caps')

        caps = caps.split()

        tmp = []
        for cap in caps:
            try:
                # test if string is int, if it is, use as is.
                int(cap, 0)
                tmp.append('(' + cap + ')')
            except ValueError:
                tmp.append('CAP_MASK_LONG(CAP_' + cap.upper() + ')')

        caps = tmp

        if len(mode) == 3:
            mode = '0' + mode

        try:
            int(mode, 8)
        except ValueError:
            sys.exit('Mode must be octal characters, got: "%s"' % mode)

        if len(mode) != 4:
            sys.exit('Mode must be 3 or 4 characters, got: "%s"' % mode)

        caps_str = '|'.join(caps)

        entry = FSConfig(mode, user, group, caps_str, section_name, file_name)
        if section_name[-1] == '/':
            self._dirs.append(entry)
        else:
            self._files.append(entry)

    @property
    def files(self):
        """Get the list of FSConfig file entries.

        Returns:
             a list of FSConfig() objects for file paths.
        """
        return self._files

    @property
    def dirs(self):
        """Get the list of FSConfig dir entries.

        Returns:
            a list of FSConfig() objects for directory paths.
        """
        return self._dirs

    @property
    def aids(self):
        """Get the list of AID entries.

        Returns:
            a list of AID() objects.
        """
        return self._aids

    @staticmethod
    def _file_key(fs_config):
        """Used as the key paramter to sort.

        This is used as a the function to the key parameter of a sort.
        it wraps the string supplied in a class that implements the
        appropriate __lt__ operator for the sort on path strings. See
        StringWrapper class for more details.

        Args:
            fs_config (FSConfig): A FSConfig entry.

        Returns:
            A StringWrapper object
        """

        # Wrapper class for custom prefix matching strings
        class StringWrapper(object):
            """Wrapper class used for sorting prefix strings.

            The algorithm is as follows:
              - specified path before prefix match
                - ie foo before f*
              - lexicographical less than before other
                - ie boo before foo

            Given these paths:
            paths=['ac', 'a', 'acd', 'an', 'a*', 'aa', 'ac*']
            The sort order would be:
            paths=['a', 'aa', 'ac', 'acd', 'an', 'ac*', 'a*']
            Thus the fs_config tools will match on specified paths before
            attempting prefix, and match on the longest matching prefix.
            """

            def __init__(self, path):
                """
                Args:
                    path (str): the path string to wrap.
                """
                self.is_prefix = path[-1] == '*'
                if self.is_prefix:
                    self.path = path[:-1]
                else:
                    self.path = path

            def __lt__(self, other):

                # if were both suffixed the smallest string
                # is 'bigger'
                if self.is_prefix and other.is_prefix:
                    result = len(self.path) > len(other.path)
                # If I am an the suffix match, im bigger
                elif self.is_prefix:
                    result = False
                # If other is the suffix match, he's bigger
                elif other.is_prefix:
                    result = True
                # Alphabetical
                else:
                    result = self.path < other.path
                return result

        return StringWrapper(fs_config.path)

    @staticmethod
    def _handle_dup_and_add(name, file_name, section_name, seen):
        """Tracks and detects duplicates. Internal use only.

        Calls sys.exit() on a duplicate.

        Args:
            name (str): The name to use in the error reporting. The pretty
                name for the section.
            file_name (str): The file currently being parsed.
            section_name (str): The name of the section. This would be path
                or identifier depending on what's being parsed.
            seen (dict): The dictionary of seen things to check against.
        """
        if section_name in seen:
            dups = '"' + seen[section_name] + '" and '
            dups += file_name
            sys.exit('Duplicate %s "%s" found in files: %s' %
                     (name, section_name, dups))

        seen[section_name] = file_name


class BaseGenerator(object):
    """Interface for Generators.

    Base class for generators, generators should implement
    these method stubs.
    """

    def add_opts(self, opt_group):
        """Used to add per-generator options to the command line.

        Args:
            opt_group (argument group object): The argument group to append to.
                See the ArgParse docs for more details.
        """

        raise NotImplementedError("Not Implemented")

    def __call__(self, args):
        """This is called to do whatever magic the generator does.

        Args:
            args (dict): The arguments from ArgParse as a dictionary.
                ie if you specified an argument of foo in add_opts, access
                it via args['foo']
        """

        raise NotImplementedError("Not Implemented")


@generator('fsconfig')
class FSConfigGen(BaseGenerator):
    """Generates the android_filesystem_config.h file.

    Output is  used in generating fs_config_files and fs_config_dirs.
    """

    _GENERATED = textwrap.dedent("""\
        /*
         * THIS IS AN AUTOGENERATED FILE! DO NOT MODIFY
         */
        """)

    _INCLUDES = [
        '<private/android_filesystem_config.h>', '"generated_oem_aid.h"'
    ]

    _DEFINE_NO_DIRS = '#define NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS'
    _DEFINE_NO_FILES = '#define NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_FILES'

    _DEFAULT_WARNING = (
        '#warning No device-supplied android_filesystem_config.h,'
        ' using empty default.')

    # Long names.
    # pylint: disable=invalid-name
    _NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS_ENTRY = (
        '{ 00000, AID_ROOT, AID_ROOT, 0,'
        '"system/etc/fs_config_dirs" },')

    _NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_FILES_ENTRY = (
        '{ 00000, AID_ROOT, AID_ROOT, 0,'
        '"system/etc/fs_config_files" },')

    _IFDEF_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS = (
        '#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS')
    # pylint: enable=invalid-name

    _ENDIF = '#endif'

    _OPEN_FILE_STRUCT = (
        'static const struct fs_path_config android_device_files[] = {')

    _OPEN_DIR_STRUCT = (
        'static const struct fs_path_config android_device_dirs[] = {')

    _CLOSE_FILE_STRUCT = '};'

    _GENERIC_DEFINE = "#define %s\t%s"

    _FILE_COMMENT = '// Defined in file: \"%s\"'

    def __init__(self, *args, **kwargs):
        BaseGenerator.__init__(args, kwargs)

        self._oem_parser = None
        self._base_parser = None
        self._friendly_to_aid = None

    def add_opts(self, opt_group):

        opt_group.add_argument(
            'fsconfig', nargs='+', help='The list of fsconfig files to parse')

        opt_group.add_argument(
            '--aid-header',
            required=True,
            help='An android_filesystem_config.h file'
            ' to parse AIDs and OEM Ranges from')

    def __call__(self, args):

        self._base_parser = AIDHeaderParser(args['aid_header'])
        self._oem_parser = FSConfigFileParser(args['fsconfig'],
                                              self._base_parser.oem_ranges)
        base_aids = self._base_parser.aids
        oem_aids = self._oem_parser.aids

        # Detect name collisions on AIDs. Since friendly works as the
        # identifier for collision testing and we need friendly later on for
        # name resolution, just calculate and use friendly.
        # {aid.friendly: aid for aid in base_aids}
        base_friendly = {aid.friendly: aid for aid in base_aids}
        oem_friendly = {aid.friendly: aid for aid in oem_aids}

        base_set = set(base_friendly.keys())
        oem_set = set(oem_friendly.keys())

        common = base_set & oem_set

        if len(common) > 0:
            emsg = 'Following AID Collisions detected for: \n'
            for friendly in common:
                base = base_friendly[friendly]
                oem = oem_friendly[friendly]
                emsg += (
                    'Identifier: "%s" Friendly Name: "%s" '
                    'found in file "%s" and "%s"' %
                    (base.identifier, base.friendly, base.found, oem.found))
                sys.exit(emsg)

        self._friendly_to_aid = oem_friendly
        self._friendly_to_aid.update(base_friendly)

        self._generate()

    def _to_fs_entry(self, fs_config):
        """Converts an FSConfig entry to an fs entry.

        Prints '{ mode, user, group, caps, "path" },'.

        Calls sys.exit() on error.

        Args:
            fs_config (FSConfig): The entry to convert to
                a valid C array entry.
        """

        # Get some short names
        mode = fs_config.mode
        user = fs_config.user
        group = fs_config.group
        fname = fs_config.filename
        caps = fs_config.caps
        path = fs_config.path

        emsg = 'Cannot convert friendly name "%s" to identifier!'

        # remap friendly names to identifier names
        if AID.is_friendly(user):
            if user not in self._friendly_to_aid:
                sys.exit(emsg % user)
            user = self._friendly_to_aid[user].identifier

        if AID.is_friendly(group):
            if group not in self._friendly_to_aid:
                sys.exit(emsg % group)
            group = self._friendly_to_aid[group].identifier

        fmt = '{ %s, %s, %s, %s, "%s" },'

        expanded = fmt % (mode, user, group, caps, path)

        print FSConfigGen._FILE_COMMENT % fname
        print '    ' + expanded

    @staticmethod
    def _gen_inc():
        """Generate the include header lines and print to stdout."""
        for include in FSConfigGen._INCLUDES:
            print '#include %s' % include

    def _generate(self):
        """Generates an OEM android_filesystem_config.h header file to stdout.

        Args:
            files ([FSConfig]): A list of FSConfig objects for file entries.
            dirs ([FSConfig]): A list of FSConfig objects for directory
                entries.
            aids ([AIDS]): A list of AID objects for Android Id entries.
        """
        print FSConfigGen._GENERATED
        print

        FSConfigGen._gen_inc()
        print

        dirs = self._oem_parser.dirs
        files = self._oem_parser.files
        aids = self._oem_parser.aids

        are_dirs = len(dirs) > 0
        are_files = len(files) > 0
        are_aids = len(aids) > 0

        if are_aids:
            for aid in aids:
                # use the preserved _path value
                print FSConfigGen._FILE_COMMENT % aid.found
                print FSConfigGen._GENERIC_DEFINE % (aid.identifier, aid.value)

            print

        if not are_dirs:
            print FSConfigGen._DEFINE_NO_DIRS + '\n'

        if not are_files:
            print FSConfigGen._DEFINE_NO_FILES + '\n'

        if not are_files and not are_dirs and not are_aids:
            return

        if are_files:
            print FSConfigGen._OPEN_FILE_STRUCT
            for fs_config in files:
                self._to_fs_entry(fs_config)

            if not are_dirs:
                print FSConfigGen._IFDEF_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
                print(
                    '    ' +
                    FSConfigGen._NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS_ENTRY)
                print FSConfigGen._ENDIF
            print FSConfigGen._CLOSE_FILE_STRUCT

        if are_dirs:
            print FSConfigGen._OPEN_DIR_STRUCT
            for dir_entry in dirs:
                self._to_fs_entry(dir_entry)

            print FSConfigGen._CLOSE_FILE_STRUCT


@generator('aidarray')
class AIDArrayGen(BaseGenerator):
    """Generates the android_id static array."""

    _GENERATED = ('/*\n'
                  ' * THIS IS AN AUTOGENERATED FILE! DO NOT MODIFY!\n'
                  ' */')

    _INCLUDE = '#include <private/android_filesystem_config.h>'

    _STRUCT_FS_CONFIG = textwrap.dedent("""
                         struct android_id_info {
                             const char *name;
                             unsigned aid;
                         };""")

    _OPEN_ID_ARRAY = 'static const struct android_id_info android_ids[] = {'

    _ID_ENTRY = '    { "%s", %s },'

    _CLOSE_FILE_STRUCT = '};'

    _COUNT = ('#define android_id_count \\\n'
              '    (sizeof(android_ids) / sizeof(android_ids[0]))')

    def add_opts(self, opt_group):

        opt_group.add_argument(
            'hdrfile', help='The android_filesystem_config.h'
            'file to parse')

    def __call__(self, args):

        hdr = AIDHeaderParser(args['hdrfile'])

        print AIDArrayGen._GENERATED
        print
        print AIDArrayGen._INCLUDE
        print
        print AIDArrayGen._STRUCT_FS_CONFIG
        print
        print AIDArrayGen._OPEN_ID_ARRAY

        for aid in hdr.aids:
            print AIDArrayGen._ID_ENTRY % (aid.friendly, aid.identifier)

        print AIDArrayGen._CLOSE_FILE_STRUCT
        print
        print AIDArrayGen._COUNT
        print


@generator('oemaid')
class OEMAidGen(BaseGenerator):
    """Generates the OEM AID_<name> value header file."""

    _GENERATED = ('/*\n'
                  ' * THIS IS AN AUTOGENERATED FILE! DO NOT MODIFY!\n'
                  ' */')

    _GENERIC_DEFINE = "#define %s\t%s"

    _FILE_COMMENT = '// Defined in file: \"%s\"'

    # Intentional trailing newline for readability.
    _FILE_IFNDEF_DEFINE = ('#ifndef GENERATED_OEM_AIDS_H_\n'
                           '#define GENERATED_OEM_AIDS_H_\n')

    _FILE_ENDIF = '#endif'

    def __init__(self):

        self._old_file = None

    def add_opts(self, opt_group):

        opt_group.add_argument(
            'fsconfig', nargs='+', help='The list of fsconfig files to parse.')

        opt_group.add_argument(
            '--aid-header',
            required=True,
            help='An android_filesystem_config.h file'
            'to parse AIDs and OEM Ranges from')

    def __call__(self, args):

        hdr_parser = AIDHeaderParser(args['aid_header'])

        parser = FSConfigFileParser(args['fsconfig'], hdr_parser.oem_ranges)

        print OEMAidGen._GENERATED

        print OEMAidGen._FILE_IFNDEF_DEFINE

        for aid in parser.aids:
            self._print_aid(aid)
            print

        print OEMAidGen._FILE_ENDIF

    def _print_aid(self, aid):
        """Prints a valid #define AID identifier to stdout.

        Args:
            aid to print
        """

        # print the source file location of the AID
        found_file = aid.found
        if found_file != self._old_file:
            print OEMAidGen._FILE_COMMENT % found_file
            self._old_file = found_file

        print OEMAidGen._GENERIC_DEFINE % (aid.identifier, aid.value)


@generator('passwd')
class PasswdGen(BaseGenerator):
    """Generates the /etc/passwd file per man (5) passwd."""

    def __init__(self):

        self._old_file = None

    def add_opts(self, opt_group):

        opt_group.add_argument(
            'fsconfig', nargs='+', help='The list of fsconfig files to parse.')

        opt_group.add_argument(
            '--aid-header',
            required=True,
            help='An android_filesystem_config.h file'
            'to parse AIDs and OEM Ranges from')

        opt_group.add_argument(
            '--required-prefix',
            required=False,
            help='A prefix that the names are required to contain.')

    def __call__(self, args):

        hdr_parser = AIDHeaderParser(args['aid_header'])

        parser = FSConfigFileParser(args['fsconfig'], hdr_parser.oem_ranges)

        required_prefix = args['required_prefix']

        aids = parser.aids

        # nothing to do if no aids defined
        if len(aids) == 0:
            return

        for aid in aids:
            if required_prefix is None or aid.friendly.startswith(required_prefix):
                self._print_formatted_line(aid)
            else:
                sys.exit("%s: AID '%s' must start with '%s'" %
                         (args['fsconfig'], aid.friendly, required_prefix))

    def _print_formatted_line(self, aid):
        """Prints the aid to stdout in the passwd format. Internal use only.

        Colon delimited:
            login name, friendly name
            encrypted password (optional)
            uid (int)
            gid (int)
            User name or comment field
            home directory
            interpreter (optional)

        Args:
            aid (AID): The aid to print.
        """
        if self._old_file != aid.found:
            self._old_file = aid.found

        try:
            logon, uid = Utils.get_login_and_uid_cleansed(aid)
        except ValueError as exception:
            sys.exit(exception)

        print "%s::%s:%s::/:/system/bin/sh" % (logon, uid, uid)


@generator('group')
class GroupGen(PasswdGen):
    """Generates the /etc/group file per man (5) group."""

    # Overrides parent
    def _print_formatted_line(self, aid):
        """Prints the aid to stdout in the group format. Internal use only.

        Formatted (per man 5 group) like:
            group_name:password:GID:user_list

        Args:
            aid (AID): The aid to print.
        """
        if self._old_file != aid.found:
            self._old_file = aid.found

        try:
            logon, uid = Utils.get_login_and_uid_cleansed(aid)
        except ValueError as exception:
            sys.exit(exception)

        print "%s::%s:" % (logon, uid)


def main():
    """Main entry point for execution."""

    opt_parser = argparse.ArgumentParser(
        description='A tool for parsing fsconfig config files and producing' +
        'digestable outputs.')
    subparser = opt_parser.add_subparsers(help='generators')

    gens = generator.get()

    # for each gen, instantiate and add them as an option
    for name, gen in gens.iteritems():

        generator_option_parser = subparser.add_parser(name, help=gen.__doc__)
        generator_option_parser.set_defaults(which=name)

        opt_group = generator_option_parser.add_argument_group(name +
                                                               ' options')
        gen.add_opts(opt_group)

    args = opt_parser.parse_args()

    args_as_dict = vars(args)
    which = args_as_dict['which']
    del args_as_dict['which']

    gens[which](args_as_dict)


if __name__ == '__main__':
    main()
