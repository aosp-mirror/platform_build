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

package android.aconfig.storage.test;

import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import android.aconfig.storage.AconfigStorageReadAPI;
import android.aconfig.storage.PackageReadContext;
import android.aconfig.storage.FlagReadContext;
import android.aconfig.storage.FlagReadContext.StoredFlagType;
import android.aconfig.storage.BooleanFlagValue;

@RunWith(JUnit4.class)
public class AconfigStorageReadAPITest{

    private String mStorageDir = "/data/local/tmp/aconfig_java_api_test";

    @Test
    public void testPackageContextQuery() {
        MappedByteBuffer packageMap = null;
        try {
            packageMap = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/maps/mockup.package.map");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(packageMap != null);

        PackageReadContext context = AconfigStorageReadAPI.getPackageReadContext(
            packageMap, "com.android.aconfig.storage.test_1");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertTrue(context.mPackageExists);
        assertEquals(context.mPackageId, 0);
        assertEquals(context.mBooleanStartIndex, 0);

        context = AconfigStorageReadAPI.getPackageReadContext(
            packageMap, "com.android.aconfig.storage.test_2");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertTrue(context.mPackageExists);
        assertEquals(context.mPackageId, 1);
        assertEquals(context.mBooleanStartIndex, 3);

        context = AconfigStorageReadAPI.getPackageReadContext(
            packageMap, "com.android.aconfig.storage.test_4");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertTrue(context.mPackageExists);
        assertEquals(context.mPackageId, 2);
        assertEquals(context.mBooleanStartIndex, 6);
    }

    @Test
    public void testNonExistPackageContextQuery() {
        MappedByteBuffer packageMap = null;
        try {
            packageMap = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/maps/mockup.package.map");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(packageMap != null);

        PackageReadContext context = AconfigStorageReadAPI.getPackageReadContext(
            packageMap, "unknown");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertFalse(context.mPackageExists);
        assertEquals(context.mPackageId, 0);
        assertEquals(context.mBooleanStartIndex, 0);
    }

    @Test
    public void testFlagContextQuery() {
        MappedByteBuffer flagMap = null;
        try {
            flagMap = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/maps/mockup.flag.map");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(flagMap!= null);

        class Baseline {
            public int mPackageId;
            public String mFlagName;
            public StoredFlagType mFlagType;
            public int mFlagIndex;

            public Baseline(int packageId,
                    String flagName,
                    StoredFlagType flagType,
                    int flagIndex) {
                mPackageId = packageId;
                mFlagName = flagName;
                mFlagType = flagType;
                mFlagIndex = flagIndex;
            }
        }

        List<Baseline> baselines = new ArrayList();
        baselines.add(new Baseline(0, "enabled_ro", StoredFlagType.ReadOnlyBoolean, 1));
        baselines.add(new Baseline(0, "enabled_rw", StoredFlagType.ReadWriteBoolean, 2));
        baselines.add(new Baseline(2, "enabled_rw", StoredFlagType.ReadWriteBoolean, 1));
        baselines.add(new Baseline(1, "disabled_rw", StoredFlagType.ReadWriteBoolean, 0));
        baselines.add(new Baseline(1, "enabled_fixed_ro", StoredFlagType.FixedReadOnlyBoolean, 1));
        baselines.add(new Baseline(1, "enabled_ro", StoredFlagType.ReadOnlyBoolean, 2));
        baselines.add(new Baseline(2, "enabled_fixed_ro", StoredFlagType.FixedReadOnlyBoolean, 0));
        baselines.add(new Baseline(0, "disabled_rw", StoredFlagType.ReadWriteBoolean, 0));

        for (Baseline baseline : baselines) {
            FlagReadContext context = AconfigStorageReadAPI.getFlagReadContext(
                flagMap, baseline.mPackageId,  baseline.mFlagName);
            assertTrue(context.mQuerySuccess);
            assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
            assertTrue(context.mFlagExists);
            assertEquals(context.mFlagType, baseline.mFlagType);
            assertEquals(context.mFlagIndex, baseline.mFlagIndex);
        }
    }

    @Test
    public void testNonExistFlagContextQuery() {
        MappedByteBuffer flagMap = null;
        try {
            flagMap = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/maps/mockup.flag.map");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(flagMap!= null);

        FlagReadContext context = AconfigStorageReadAPI.getFlagReadContext(
            flagMap, 0,  "unknown");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertFalse(context.mFlagExists);
        assertEquals(context.mFlagType, null);
        assertEquals(context.mFlagIndex, 0);

        context = AconfigStorageReadAPI.getFlagReadContext(
            flagMap, 3,  "enabled_ro");
        assertTrue(context.mQuerySuccess);
        assertTrue(context.mErrorMessage, context.mErrorMessage.equals(""));
        assertFalse(context.mFlagExists);
        assertEquals(context.mFlagType, null);
        assertEquals(context.mFlagIndex, 0);
    }

    @Test
    public void testBooleanFlagValueQuery() {
        MappedByteBuffer flagVal = null;
        try {
            flagVal = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/boot/mockup.val");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(flagVal!= null);

        boolean[] baselines = {false, true, true, false, true, true, true, true};
        for (int i = 0; i < 8; ++i) {
            BooleanFlagValue value = AconfigStorageReadAPI.getBooleanFlagValue(flagVal, i);
            assertTrue(value.mQuerySuccess);
            assertTrue(value.mErrorMessage, value.mErrorMessage.equals(""));
            assertEquals(value.mFlagValue, baselines[i]);
        }
    }

    @Test
    public void testInvalidBooleanFlagValueQuery() {
        MappedByteBuffer flagVal = null;
        try {
            flagVal = AconfigStorageReadAPI.mapStorageFile(
                mStorageDir + "/boot/mockup.val");
        } catch(IOException ex){
            assertTrue(ex.toString(), false);
        }
        assertTrue(flagVal!= null);

        BooleanFlagValue value = AconfigStorageReadAPI.getBooleanFlagValue(flagVal, 9);
        String expectedErrmsg = "Flag value offset goes beyond the end of the file";
        assertFalse(value.mQuerySuccess);
        assertTrue(value.mErrorMessage, value.mErrorMessage.contains(expectedErrmsg));
    }
 }
