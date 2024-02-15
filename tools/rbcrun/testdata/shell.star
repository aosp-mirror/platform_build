# Tests "queue" data type
load("assert.star", "assert")

assert.eq("load.star shell.star", rblf_shell("ls -1 shell.star load.star 2>&1"))
assert.eq("shell.star", rblf_shell("echo shell.sta*"))
