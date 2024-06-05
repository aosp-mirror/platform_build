# Tests file ops builtins
load("assert.star", "assert")

def test():
    myname = "file_ops.star"
    files = rblf_wildcard("*.star")
    assert.true(myname in files, "expected %s in  %s" % (myname, files))
    files = rblf_wildcard("*.star")
    assert.true(myname in files, "expected %s in %s" % (myname, files))
    files = rblf_wildcard("*.xxx")
    assert.true(len(files) == 0, "expansion should be empty but contains %s" % files)
    mydir = "testdata"
    myrelname = "%s/%s" % (mydir, myname)
    files = rblf_find_files("../", "*")
    assert.true(mydir in files and myrelname in files, "expected %s and %s in %s" % (mydir, myrelname, files))
    files = rblf_find_files("../", "*", only_files=1)
    assert.true(mydir not in files, "did not expect %s in %s" % (mydir, files))
    assert.true(myrelname in files, "expected %s  in %s" % (myrelname, files))
    files = rblf_find_files("../", "*.star")
    assert.true(myrelname in files, "expected %s in %s" % (myrelname, files))
test()
