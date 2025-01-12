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

package android.aconfig.test;

import static org.junit.Assert.assertTrue;

import android.aconfig.DeviceProtosTestUtil;
import android.aconfig.nano.Aconfig.parsed_flag;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.util.List;
import java.util.Set;

@RunWith(JUnit4.class)
public class DeviceProtosTestUtilTest {

    private static final Set<String> PLATFORM_CONTAINERS = Set.of("system", "vendor", "product");

    @Test
    public void testDeviceProtos_loadAndParseFlagProtos() throws Exception {
        List<parsed_flag> flags = DeviceProtosTestUtil.loadAndParseFlagProtos();
        int platformFlags = 0;
        int mainlineFlags = 0;
        for (parsed_flag pf : flags) {
            if (PLATFORM_CONTAINERS.contains(pf.container)) {
                platformFlags++;
            } else {
                mainlineFlags++;
            }
        }

        assertTrue(platformFlags > 3);
        assertTrue(mainlineFlags > 3);
    }
}
