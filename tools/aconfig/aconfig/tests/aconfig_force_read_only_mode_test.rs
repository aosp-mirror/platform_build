#[cfg(not(feature = "cargo"))]
#[test]
fn test_flags() {
    assert!(!aconfig_test_rust_library::disabled_ro());
    assert!(!aconfig_test_rust_library::disabled_rw());
    assert!(!aconfig_test_rust_library::disabled_rw_in_other_namespace());
    assert!(aconfig_test_rust_library::enabled_fixed_ro());
    assert!(aconfig_test_rust_library::enabled_ro());
    assert!(aconfig_test_rust_library::enabled_rw());
}
