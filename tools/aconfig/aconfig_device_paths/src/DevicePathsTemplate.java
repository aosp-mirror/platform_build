/*
 * Copyright (C) 2024 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package android.aconfig;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * @hide
 */
public class DevicePaths {
    static final String[] PATHS = {
        TEMPLATE
    };

    private static final String APEX_DIR = "/apex";
    private static final String APEX_ACONFIG_PATH_SUFFIX = "/etc/aconfig_flags.pb";


    /**
     * Returns the list of all on-device aconfig protos paths.
     * @hide
     */
    public List<String> parsedFlagsProtoPaths() {
        ArrayList<String> paths = new ArrayList(Arrays.asList(PATHS));

        File apexDirectory = new File(APEX_DIR);
        if (!apexDirectory.isDirectory()) {
            return paths;
        }

        File[] subdirs = apexDirectory.listFiles();
        if (subdirs == null) {
            return paths;
        }

        for (File prefix : subdirs) {
            // For each mainline modules, there are two directories, one <modulepackage>/,
            // and one <modulepackage>@<versioncode>/. Just read the former.
            if (prefix.getAbsolutePath().contains("@")) {
                continue;
            }

            File protoPath = new File(prefix + APEX_ACONFIG_PATH_SUFFIX);
            if (!protoPath.exists()) {
                continue;
            }

            paths.add(protoPath.getAbsolutePath());
        }
        return paths;
    }
}
