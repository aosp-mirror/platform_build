/*
 * Copyright (C) 2008 The Android Open Source Project
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

package com.android.apicheck;
import java.util.*;

public class PackageInfo {
    private String mName;
    private HashMap<String, ClassInfo> mClasses;
    private boolean mExistsInBoth;
    private SourcePositionInfo mPosition;
    
    public PackageInfo(String name, SourcePositionInfo position) {
        mName = name;
        mClasses = new HashMap<String, ClassInfo>();
        mExistsInBoth = false;
        mPosition = position;
    }
    
    public void addClass(ClassInfo cl) {
        mClasses.put(cl.name() , cl);
    }
    
    public HashMap<String, ClassInfo> allClasses() {
        return mClasses;
    }
    
    public String name() {
        return mName;
    }
    
    public SourcePositionInfo position() {
        return mPosition;
    }
    
    public boolean isConsistent(PackageInfo pInfo) {
        mExistsInBoth = true;
        pInfo.mExistsInBoth = true;
        boolean consistent = true;
        for (ClassInfo cInfo : mClasses.values()) {
            if (pInfo.mClasses.containsKey(cInfo.name())) {
                if (!cInfo.isConsistent(pInfo.mClasses.get(cInfo.name()))) {
                    consistent = false;
                }
            } else {
                Errors.error(Errors.REMOVED_CLASS, cInfo.position(),
                        "Removed public class " + cInfo.qualifiedName());
                consistent = false;
            }
        }
        for (ClassInfo cInfo : pInfo.mClasses.values()) {
            if (!cInfo.isInBoth()) {
                Errors.error(Errors.ADDED_CLASS, cInfo.position(),
                        "Added class " + cInfo.name() + " to package "
                        + pInfo.name());
                consistent = false;
            }
        }
        return consistent;
    }
    
    public boolean isInBoth() {
        return mExistsInBoth;
    }
}
