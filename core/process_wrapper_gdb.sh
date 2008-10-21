#!/bin/sh

# This is the command running inside the xterm of our
# debug wrapper.  It needs to take care of starting
# the server command, so it can attach to the parent
# process.  In addition, here we run the command inside
# of a gdb session to allow for debugging.

# On some systems, running xterm will cause LD_LIBRARY_PATH
# to be cleared, so restore it and PATH to be safe.
export PATH=$PREV_PATH
export LD_LIBRARY_PATH=$PREV_LD_LIBRARY_PATH

# Start binderproc (or whatever sub-command is being run)
# inside of gdb, giving gdb an initial command script to
# automatically run the process without user intervention.
gdb -q -x $2/process_wrapper_gdb.cmds --args "$@"
