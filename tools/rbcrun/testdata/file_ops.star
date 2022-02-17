# Tests file ops builtins
load("assert.star", "assert")


def test():
    myname = "file_ops.star"
    assert.true(rblf_file_exists("."), "./ exists ")
    assert.true(rblf_file_exists(myname), "the file %s does exist" % myname)
    assert.true(not rblf_file_exists("no_such_file"), "the file no_such_file does not exist")
    files = rblf_wildcard("*.star")
    assert.true(myname in files, "expected %s in  %s" % (myname, files))
    files = rblf_wildcard("*.star", rblf_env.TEST_DATA_DIR)
    assert.true(myname in files, "expected %s in %s" % (myname, files))
    files = rblf_wildcard("*.xxx")
    assert.true(len(files) == 0, "expansion should be empty but contains %s" % files)
    mydir = "testdata"
    myrelname = "%s/%s" % (mydir, myname)
    files = rblf_find_files(rblf_env.TEST_DATA_DIR + "/../", "*")
    assert.true(mydir in files and myrelname in files, "expected %s and %s in %s" % (mydir, myrelname, files))
    files = rblf_find_files(rblf_env.TEST_DATA_DIR + "/../", "*", only_files=1)
    assert.true(mydir not in files, "did not expect %s in %s" % (mydir, files))
    assert.true(myrelname in files, "expected %s  in %s" % (myrelname, files))
    files = rblf_find_files(rblf_env.TEST_DATA_DIR + "/../", "*.star")
    assert.true(myrelname in files, "expected %s in %s" % (myrelname, files))
test()
