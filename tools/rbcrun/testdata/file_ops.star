# Tests file ops builtins
load("assert.star", "assert")


def test():
    myname = "file_ops.star"
    assert.true(rblf_file_exists(myname), "the file %s does exist" % myname)
    assert.true(not rblf_file_exists("no_such_file"), "the file no_such_file does not exist")
    files = rblf_wildcard("*.star")
    assert.true(myname in files, "expected %s in  %s" % (myname, files))
    # RBCDATADIR is set by the caller to the path where this file resides
    files = rblf_wildcard("*.star", rblf_env.TEST_DATA_DIR)
    assert.true(myname in files, "expected %s in %s" % (myname, files))
    files = rblf_wildcard("*.xxx")
    assert.true(len(files) == 0, "expansion should be empty but contains %s" % files)


test()
