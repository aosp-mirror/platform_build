# `dex_preopt_check`

`dex_preopt_check` is a build-time check to make sure that all system server
jars are dexpreopted. When the check fails, you will see the following error
message:

```
FAILED:
build/make/core/tasks/dex_preopt_check.mk:13: warning:  Missing compilation artifacts. Dexpreopting is not working for some system server jars
Offending entries:
```

Possible causes are:

1.  There is an APEX/SDK mismatch. (E.g., the APEX is built from source while
    the SDK is built from prebuilt.)

1.  The `systemserverclasspath_fragment` is not added as
    `systemserverclasspath_fragments` of the corresponding `apex` module, or not
    added as `exported_systemserverclasspath_fragments` of the corresponding
    `prebuilt_apex`/`apex_set` module when building from prebuilt.

1.  The expected version of the system server java library is not preferred.
    (E.g., the `java_import` module has `prefer: false` when building from
    prebuilt.)

1.  Dexpreopting is disabled for the system server java library. This can be due
    to various reasons including but not limited to:

    - The java library has `dex_preopt: { enabled: false }` in the Android.bp
      file.

    - The java library is listed in `DEXPREOPT_DISABLED_MODULES` in a Makefile.

    - The java library is missing `installable: true` in the Android.bp
      file when building from source.

    - Sanitizer is enabled.

1.  `PRODUCT_SYSTEM_SERVER_JARS`, `PRODUCT_APEX_SYSTEM_SERVER_JARS`,
    `PRODUCT_STANDALONE_SYSTEM_SERVER_JARS`, or
    `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS` has an extra entry that is not
    needed by the product.
