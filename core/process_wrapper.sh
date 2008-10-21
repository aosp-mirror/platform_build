#!/bin/sh

# When using a process wrapper, this is the top-level
# command that is executed instead of the server
# command.  It starts a new xterm in which the user can
# interact with the new process.
#
# Inside of the xterm is a gdb session, through which
# the user can debug the new process.

# Save away these variables, since we may loose them
# when starting in the xterm.
export PREV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export PREV_PATH=$PATH

gnome-terminal -t "Wrapper: $1" --disable-factory -x $2/process_wrapper_gdb.sh "$@"

