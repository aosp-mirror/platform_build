#[cfg(not(feature = "cargo"))]
#[test]
fn test_flags() {
    assert!(!aconfig_test_rust_library::disabled_rw_exported());
    assert!(!aconfig_test_rust_library::enabled_fixed_ro_exported());
    assert!(!aconfig_test_rust_library::enabled_ro_exported());
}
