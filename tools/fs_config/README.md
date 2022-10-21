# FS Config Generator

The `fs_config_generator.py` tool uses the platform `android_filesystem_config.h` and the
`TARGET_FS_CONFIG_GEN` files to generate the following:
* `fs_config_dirs` and `fs_config_files` files for each partition
* `passwd` and `group` files for each partition
* The `generated_oem_aid.h` header

## Outputs

### `fs_config_dirs` and `fs_config_files`

The `fs_config_dirs` and `fs_config_files` binary files are interpreted by the libcutils
`fs_config()` function, along with the built-in defaults, to serve as overrides to complete the
results. The Target files are used by filesystem and adb tools to ensure that the file and directory
properties are preserved during runtime operations. The host files in the `$OUT` directory are used
in the final stages when building the filesystem images to set the file and directory properties.

See `./fs_config_generator.py fsconfig --help` for how these files are generated.

### `passwd` and `group` files

The `passwd` and `group` files are formatted as documented in man pages passwd(5) and group(5) and
used by bionic for implementing `getpwnam()` and related functions.

See `./fs_config_generator.py passwd --help` and `./fs_config_generator.py group --help` for how
these files are generated.

### The `generated_oem_aid.h` header

The `generated_oem_aid.h` creates identifiers for non-platform AIDs for developers wishing to use
them in their native code.  To do so, include the `oemaids_headers` header library in the
corresponding makefile and `#include "generated_oem_aid.h"` in the code wishing to use these
identifiers.

See `./fs_config_generator.py oemaid --help` for how this file is generated.

## Parsing

See the documentation on [source.android.com](https://source.android.com/devices/tech/config/filesystem#configuring-aids) for details and examples.


## Ordering

Ordering within the `TARGET_FS_CONFIG_GEN` files is not relevant. The paths for files are sorted
like so within their respective array definition:
 * specified path before prefix match
   * for example: foo before f*
 * lexicographical less than before other
   * for example: boo before foo

Given these paths:

    paths=['ac', 'a', 'acd', 'an', 'a*', 'aa', 'ac*']

The sort order would be:

    paths=['a', 'aa', 'ac', 'acd', 'an', 'ac*', 'a*']

Thus the `fs_config` tools will match on specified paths before attempting prefix, and match on the
longest matching prefix.

The declared AIDs are sorted in ascending numerical order based on the option "value". The string
representation of value is preserved. Both choices were made for maximum readability of the
generated file and to line up files. Sync lines are placed with the source file as comments in the
generated header file.

## Unit Tests

From within the `fs_config` directory, unit tests can be executed like so:

    $ python test_fs_config_generator.py
    ................
    ----------------------------------------------------------------------
    Ran 16 tests in 0.004s
    OK


One could also use nose if they would like:

    $ nose2

To add new tests, simply add a `test_<xxx>` method to the test class. It will automatically
get picked up and added to the test suite.
