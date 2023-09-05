#[cfg(not(feature = "cargo"))]
#[test]
fn test_flags() {
    assert!(!aconfig_test_rust_library::disabled_ro());
    assert!(!aconfig_test_rust_library::disabled_rw());
    // TODO: Fix template to not default both disabled and enabled to false
    assert!(!aconfig_test_rust_library::enabled_ro());
    assert!(!aconfig_test_rust_library::enabled_rw());

    aconfig_test_rust_library::set_disabled_ro(true);
    assert!(aconfig_test_rust_library::disabled_ro());
    aconfig_test_rust_library::set_disabled_rw(true);
    assert!(aconfig_test_rust_library::disabled_rw());
    aconfig_test_rust_library::set_enabled_ro(true);
    assert!(aconfig_test_rust_library::enabled_ro());
    aconfig_test_rust_library::set_enabled_rw(true);
    assert!(aconfig_test_rust_library::enabled_rw());

    aconfig_test_rust_library::reset_flags();
    assert!(!aconfig_test_rust_library::disabled_ro());
    assert!(!aconfig_test_rust_library::disabled_rw());
    assert!(!aconfig_test_rust_library::enabled_ro());
    assert!(!aconfig_test_rust_library::enabled_rw());
}
