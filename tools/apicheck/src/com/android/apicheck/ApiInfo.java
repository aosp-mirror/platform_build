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

public class ApiInfo {
  
    private HashMap<String, PackageInfo> mPackages;
    private HashMap<String, ClassInfo> mAllClasses;
    
    public ApiInfo() {
        mPackages = new HashMap<String, PackageInfo>();
        mAllClasses = new HashMap<String, ClassInfo>();
    }

    public ClassInfo findClass(String name) {
        return mAllClasses.get(name);
    }

    public void resolveInterfaces() {
        for (ClassInfo c : mAllClasses.values()) {
            c.resolveInterfaces(this);
        }
    }
    
    public boolean isConsistent(ApiInfo otherApi) {
        boolean consistent = true;
        for (PackageInfo pInfo : mPackages.values()) {
            if (otherApi.getPackages().containsKey(pInfo.name())) {
                if (!pInfo.isConsistent(otherApi.getPackages().get(pInfo.name()))) {
                    consistent = false;
                }
            } else {
                Errors.error(Errors.REMOVED_PACKAGE, pInfo.position(),
                        "Removed package " + pInfo.name());
                consistent = false;
            }
        }
        for (PackageInfo pInfo : otherApi.mPackages.values()) {
            if (!pInfo.isInBoth()) {
                Errors.error(Errors.ADDED_PACKAGE, pInfo.position(),
                        "Added package " + pInfo.name());
                consistent = false;
            }
        }
        return consistent;
    }
    
    public HashMap<String, PackageInfo> getPackages() {
        return mPackages;
    }
    
    public void addPackage(PackageInfo pInfo) {
        // track the set of organized packages in the API
        mPackages.put(pInfo.name(), pInfo);
        
        // accumulate a direct map of all the classes in the API
        for (ClassInfo cl: pInfo.allClasses().values()) {
            mAllClasses.put(cl.qualifiedName(), cl);
        }
    }

    public void resolveSuperclasses() {
        for (ClassInfo cl: mAllClasses.values()) {
            // java.lang.Object has no superclass
            if (!cl.qualifiedName().equals("java.lang.Object")) {
                String scName = cl.superclassName();
                if (scName == null) {
                    scName = "java.lang.Object";
                }

                ClassInfo superclass = mAllClasses.get(scName);
                cl.setSuperClass(superclass);
            }
        }
    }
}
