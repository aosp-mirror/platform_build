# Test load, simple and conditional
load("assert.star", "assert")
load(":module1.star", test1="test")
load("//testdata:module2.star", test2="test")
load(":module3|test", test3="test")


def test():
    assert.eq(test1, "module1")
    assert.eq(test2, "module2")
    assert.eq(test3, None)


test()
