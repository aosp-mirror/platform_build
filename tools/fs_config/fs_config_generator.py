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


class AID(object):
    """This class represents an Android ID or an AID.

    Attributes:
        identifier (str): The identifier name for a #define.
        value (str) The User Id (uid) of the associate define.
        found (str) The file it was found in, can be None.
        normalized_value (str): Same as value, but base 10.
    """

    def __init__(self, identifier, value, found):
        """
        Args:
            identifier: The identifier name for a #define <identifier>.
            value: The value of the AID, aka the uid.
            found (str): The file found in, not required to be specified.

        Raises:
            ValueError: if value is not a valid string number as processed by
                int(x, 0)
        """
        self.identifier = identifier
        self.value = value
        self.found = found
        self.normalized_value = str(int(value, 0))


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


class FSConfigFileParser(object):
    """Parses a config.fs ini format file.

    This class is responsible for parsing the config.fs ini format files.
    It collects and checks all the data in these files and makes it available
    for consumption post processed.
    """
    # from system/core/include/private/android_filesystem_config.h
    _AID_OEM_RESERVED_RANGES = [
        (2900, 2999),
        (5000, 5999),
    ]

    _AID_MATCH = re.compile('AID_[a-zA-Z]+')

    def __init__(self, config_files):
        """
        Args:
            config_files ([str]): The list of config.fs files to parse.
                Note the filename is not important.
        """

        self._files = []
        self._dirs = []
        self._aids = []

        self._seen_paths = {}
        # (name to file, value to aid)
        self._seen_aids = ({}, {})

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

            if FSConfigFileParser._AID_MATCH.match(
                    section) and config.has_option(section, 'value'):
                FSConfigFileParser._handle_dup('AID', file_name, section,
                                               self._seen_aids[0])
                self._seen_aids[0][section] = file_name
                self._handle_aid(file_name, section, config)
            else:
                FSConfigFileParser._handle_dup('path', file_name, section,
                                               self._seen_paths)
                self._seen_paths[section] = file_name
                self._handle_path(file_name, section, config)

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

        value = config.get(section_name, 'value')

        if not value:
            sys.exit(error_message('Found specified but unset "value"'))

        try:
            aid = AID(section_name, value, file_name)
        except ValueError:
            sys.exit(
                error_message('Invalid "value", not aid number, got: \"%s\"' %
                              value))

        # Values must be within OEM range.
        if not any(lower <= int(aid.value, 0) <= upper
                   for (lower, upper
                       ) in FSConfigFileParser._AID_OEM_RESERVED_RANGES):
            emsg = '"value" not in valid range %s, got: %s'
            emsg = emsg % (str(FSConfigFileParser._AID_OEM_RESERVED_RANGES),
                           value)
            sys.exit(error_message(emsg))

        # use the normalized int value in the dict and detect
        # duplicate definitions of the same value
        if aid.normalized_value in self._seen_aids[1]:
            # map of value to aid name
            aid = self._seen_aids[1][aid.normalized_value]

            # aid name to file
            file_name = self._seen_aids[0][aid]

            emsg = 'Duplicate AID value "%s" found on AID: "%s".' % (
                value, self._seen_aids[1][aid.normalized_value])
            emsg += ' Previous found in file: "%s."' % file_name
            sys.exit(error_message(emsg))

        self._seen_aids[1][aid.normalized_value] = section_name

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
                tmp.append('(1ULL << CAP_' + cap.upper() + ')')

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
    def _handle_dup(name, file_name, section_name, seen):
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

    _INCLUDE = '#include <private/android_filesystem_config.h>'

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

    def add_opts(self, opt_group):

        opt_group.add_argument(
            'fsconfig', nargs='+', help='The list of fsconfig files to parse')

    def __call__(self, args):

        parser = FSConfigFileParser(args['fsconfig'])
        FSConfigGen._generate(parser.files, parser.dirs, parser.aids)

    @staticmethod
    def _to_fs_entry(fs_config):
        """
        Given an FSConfig entry, converts it to a proper
        array entry for the array entry.

        { mode, user, group, caps, "path" },

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

        fmt = '{ %s, %s, %s, %s, "%s" },'

        expanded = fmt % (mode, user, group, caps, path)

        print FSConfigGen._FILE_COMMENT % fname
        print '    ' + expanded

    @staticmethod
    def _generate(files, dirs, aids):
        """Generates an OEM android_filesystem_config.h header file to stdout.

        Args:
            files ([FSConfig]): A list of FSConfig objects for file entries.
            dirs ([FSConfig]): A list of FSConfig objects for directory
                entries.
            aids ([AIDS]): A list of AID objects for Android Id entries.
        """
        print FSConfigGen._GENERATED
        print FSConfigGen._INCLUDE
        print

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
            print FSConfigGen._DEFAULT_WARNING
            return

        if are_files:
            print FSConfigGen._OPEN_FILE_STRUCT
            for fs_config in files:
                FSConfigGen._to_fs_entry(fs_config)

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
                FSConfigGen._to_fs_entry(dir_entry)

            print FSConfigGen._CLOSE_FILE_STRUCT


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
