# Tests rblf_regex
load("assert.star", "assert")


def test():
    pattern = "^(foo.*bar|abc.*d|1.*)$"
    for w in ("foobar", "fooxbar", "abcxd", "123"):
        assert.true(rblf_regex(pattern, w), "%s should match %s" % (w, pattern))
    for w in ("afoobar", "abcde"):
        assert.true(not rblf_regex(pattern, w), "%s should not match %s" % (w, pattern))


test()
