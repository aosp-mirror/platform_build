# Tests "queue" data type
load("assert.star", "assert")

assert.eq("load.star shell.star", rblf_shell("cd %s && ls -1 shell.star load.star 2>&1" % rblf_env.TEST_DATA_DIR))
assert.eq("shell.star", rblf_shell("cd %s && echo shell.sta*" % rblf_env.TEST_DATA_DIR))
