#!/usr/bin/env python3
import sys
from xml.dom.minidom import parseString

def parse_package(manifest):
    with open(manifest, 'r') as f:
        data = f.read()
    dom = parseString(data)
    return dom.documentElement.getAttribute('package')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys_argv[0]} target_package_manifest output\n")
    package_name = parse_package(sys.argv[1])
    with open(sys.argv[2], "w") as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package_name}.auto_generated_characteristics_rro">
    <application android:hasCode="false" />
    <overlay android:targetPackage="{package_name}"
             android:isStatic="true"
             android:priority="0" />
</manifest>
''')
