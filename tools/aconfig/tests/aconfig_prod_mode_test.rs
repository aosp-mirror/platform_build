#[cfg(not(feature = "cargo"))]
#[test]
fn test_flags() {
    assert!(!aconfig_test_rust_library::disabled_ro());
    assert!(!aconfig_test_rust_library::disabled_rw());
    // TODO: Fix template to not default both disabled and enabled to false
    assert!(!aconfig_test_rust_library::enabled_ro());
    assert!(!aconfig_test_rust_library::enabled_rw());
}
