Android build system usage:

m [-j] [<targets>] [<variable>=<value>...]


Ways to specify what to build:
  The common way to specify what to build is to set that information in the
  environment via:

    # Set up the shell environment.
    source build/envsetup.sh # Run "hmm" after sourcing for more info
    # Select the device and variant to target. If no argument is given, it
    # will list choices and prompt.
    lunch [<product>-<variant>] # Selects the device and variant to target.
    # Invoke the configured build.
    m [<options>] [<targets>] [<variable>=<value>...]

      <product> is the device that the created image is intended to be run on.
        This is saved in the shell environment as $TARGET_PRODUCT by `lunch`.
      <variant> is one of "user", "userdebug", or "eng", and controls the
        amount of debugging to be added into the generated image.
        This gets saved in the shell environment as $TARGET_BUILD_VARIANT by
          `lunch`.

    Each of <options>, <targets>, and <variable>=<value> is optional.
      If no targets are specified, the build system will build the images
      for the configured product and variant.

  An alternative to setting $TARGET_PRODUCT and $TARGET_BUILD_VARIANT,
  which you may see in build servers, is to execute:

    make PRODUCT-<product>-<variant>


  A target may be a file path. For example, out/host/linux-x86/bin/adb .
    Note that when giving a relative file path as a target, that path is
    interpreted relative to the root of the source tree (rather than relative
    to the current working directory).

  A target may also be any other target defined within a Makefile. Run
    `m help` to view the names of some common targets.

  To view the modules and targets defined in a particular directory, look for:
    files named *.mk (most commonly Android.mk)
      these files are defined in Make syntax
    files named Android.bp
      these files are defined in Blueprint syntax

  For now, the full (extremely large) compiled list of targets can be found
    (after running the build once), split among these two files:

    ${OUT}/build-<product>*.ninja
    ${OUT}/soong/build.ninja

    If you find yourself interacting with these files, you are encouraged to
    provide a more convenient tool for browsing targets, and to mention the
    tool here.

Targets that adjust an existing build:
  showcommands              Display the individual commands run to implement
                            the build
  dist                      Copy into ${DIST_DIR} the portion of the build
                            that must be distributed

Flags
  -j <N>                    Run <N> processes at once
  -j                        Autodetect the number of processes to run at once,
                            and run that many

Variables
  Variables can either be set in the surrounding shell environment or can be
    passed as command-line arguments. For example:
      export I_AM_A_SHELL_VAR=1
      I_AM_ANOTHER_SHELL_VAR=2 make droid I_AM_A_MAKE_VAR=3
  Here are some common variables and their meanings:
    TARGET_PRODUCT          The <product> to build # as described above
    TARGET_BUILD_VARIANT    The <variant> to build # as described above
    DIST_DIR                The directory in which to place the distribution
                            artifacts.
    OUT_DIR                 The directory in which to place non-distribution
                            artifacts.

  There is not yet known a convenient method by which to discover the full
  list of supported variables. Please mention it here when there is.

