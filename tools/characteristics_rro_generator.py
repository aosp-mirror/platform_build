#!/usr/bin/env python3
import sys

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys_argv[0]} target_package_name output\n")
    with open(sys.argv[2], "w") as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
                <manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{sys.argv[1]}.auto_generated_characteristics_rro">
    <application android:hasCode="false" />
    <overlay android:targetPackage="{sys.argv[1]}"
             android:isStatic="true"
             android:priority="0" />
</manifest>
''')
