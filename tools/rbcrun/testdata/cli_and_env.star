# Tests rblf_env access
load("assert.star", "assert")


def test():
    assert.eq(rblf_env.TEST_ENVIRONMENT_FOO, "test_environment_foo")
    assert.fails(lambda: rblf_env.FOO_BAR_BAZ, ".*struct has no .FOO_BAR_BAZ attribute$")
    assert.eq(rblf_cli.CLI_FOO, "foo")


test()
