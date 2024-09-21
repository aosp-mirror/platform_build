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
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * A host lib that can read all aconfig proto file paths on a given device.
 */
public class HostDeviceProtos {
    /**
     * An interface that executes ADB command and return the result.
     */
    public static interface AdbCommandExecutor {
        /** Executes the ADB command. */
        String executeAdbCommand(String command);
    }

    static final String[] PATHS = {
        TEMPLATE
    };

    private static final String APEX_DIR = "/apex";
    private static final String RECURSIVELY_LIST_APEX_DIR_COMMAND = "shell find /apex | grep aconfig_flags";
    private static final String APEX_ACONFIG_PATH_SUFFIX = "/etc/aconfig_flags.pb";


    /**
     * Returns the list of all on-device aconfig proto paths from host side.
     */
    public static List<String> parsedFlagsProtoPaths(AdbCommandExecutor adbCommandExecutor) {
        ArrayList<String> paths = new ArrayList(Arrays.asList(PATHS));

        String adbCommandOutput = adbCommandExecutor.executeAdbCommand(
            RECURSIVELY_LIST_APEX_DIR_COMMAND);

        if (adbCommandOutput == null) {
            return paths;
        }

        Set<String> allFiles = new HashSet<>(Arrays.asList(adbCommandOutput.split("\n")));

        Set<String> subdirs = allFiles.stream().map(file -> {
            String[] filePaths = file.split("/");
            // The first element is "", the second element is "apex".
            return filePaths.length > 2 ? filePaths[2] : "";
        }).collect(Collectors.toSet());

        for (String prefix : subdirs) {
            // For each mainline modules, there are two directories, one <modulepackage>/,
            // and one <modulepackage>@<versioncode>/. Just read the former.
            if (prefix.contains("@")) {
                continue;
            }

            String protoPath = APEX_DIR + "/" + prefix + APEX_ACONFIG_PATH_SUFFIX;
            if (allFiles.contains(protoPath)) {
                paths.add(protoPath);
            }
        }
        return paths;
    }
}
