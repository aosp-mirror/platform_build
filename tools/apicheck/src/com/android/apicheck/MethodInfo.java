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

public class MethodInfo implements AbstractMethodInfo {
  
    private String mName;
    private String mReturn;
    private boolean mIsAbstract;
    private boolean mIsNative;
    private boolean mIsSynchronized;
    private boolean mIsStatic;
    private boolean mIsFinal;
    private String mDeprecated;
    private String mScope;
    private boolean mExistsInBoth;
    private List<ParameterInfo> mParameters;
    private List<String> mExceptions;
    private SourcePositionInfo mSourcePosition;
    private ClassInfo mClass;
    
    public MethodInfo (String name, String returnType, boolean isAbstract, boolean isNative,
                        boolean isSynchronized, boolean isStatic, boolean isFinal, String deprecated
                        , String scope, SourcePositionInfo source, ClassInfo parent) {
        
        mName = name;
        mReturn = returnType;
        mIsAbstract = isAbstract;
        mIsNative = isNative;
        mIsSynchronized = isSynchronized;
        mIsStatic = isStatic;
        mIsFinal = isFinal;
        mDeprecated = deprecated;
        mScope = scope;
        mParameters = new ArrayList<ParameterInfo>();
        mExceptions = new ArrayList<String>();
        mExistsInBoth = false;
        mSourcePosition = source;
        mClass = parent;
    }
    
    
    public String name() {
        return mName;
    }
    
    public String qualifiedName() {
        String parentQName = (mClass != null)
                ? (mClass.qualifiedName() + ".")
                : "";
        return parentQName + name();
    }
    
    public String prettySignature() {
        String params = "";
        for (ParameterInfo pInfo : mParameters) {
            if (params.length() > 0) {
                params += ", ";
            }
            params += pInfo.getType();
        }
        return qualifiedName() + '(' + params + ')';
    }
    
    public SourcePositionInfo position() {
        return mSourcePosition;
    }
    
    public ClassInfo containingClass() {
        return mClass;
    }

    public boolean matches(MethodInfo other) {
        return getSignature().equals(other.getSignature());
    }
    
    public boolean isConsistent(MethodInfo mInfo) {
        mInfo.mExistsInBoth = true;
        mExistsInBoth = true;
        boolean consistent = true;
        if (!mReturn.equals(mInfo.mReturn)) {
            consistent = false;
            Errors.error(Errors.CHANGED_TYPE, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed return type from "
                    + mReturn + " to " + mInfo.mReturn);
        }
        
        if (mIsAbstract != mInfo.mIsAbstract) {
            consistent = false;
            Errors.error(Errors.CHANGED_ABSTRACT, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed 'abstract' qualifier");
        }
        
        if (mIsNative != mInfo.mIsNative) {
            consistent = false;
            Errors.error(Errors.CHANGED_NATIVE, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed 'native' qualifier");
        }
        
        if (mIsFinal != mInfo.mIsFinal) {
            // Compiler-generated methods vary in their 'final' qual between versions of
            // the compiler, so this check needs to be quite narrow.  A change in 'final'
            // status of a method is only relevant if (a) the method is not declared 'static'
            // and (b) the method's class is not itself 'final'.
            if (!mIsStatic) {
                if ((mClass == null) || (!mClass.isFinal())) {
                    consistent = false;
                    Errors.error(Errors.CHANGED_FINAL, mInfo.position(),
                            "Method " + mInfo.qualifiedName() + " has changed 'final' qualifier");
                }
            }
        }
        
        if (mIsStatic != mInfo.mIsStatic) {
            consistent = false;
            Errors.error(Errors.CHANGED_STATIC, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed 'static' qualifier");
        }
       
        if (!mScope.equals(mInfo.mScope)) {
            consistent = false;
            Errors.error(Errors.CHANGED_SCOPE, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " changed scope from "
                    + mScope + " to " + mInfo.mScope);
        }
        
        if (!mDeprecated.equals(mInfo.mDeprecated)) {
            Errors.error(Errors.CHANGED_DEPRECATED, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed deprecation state");
            consistent = false;
        }
        
        if (mIsSynchronized != mInfo.mIsSynchronized) {
            Errors.error(Errors.CHANGED_SYNCHRONIZED, mInfo.position(),
                    "Method " + mInfo.qualifiedName() + " has changed 'synchronized' qualifier from " + mIsSynchronized + " to " + mInfo.mIsSynchronized);
            consistent = false;
        }
        
        for (String exec : mExceptions) {
            if (!mInfo.mExceptions.contains(exec)) {
                // exclude 'throws' changes to finalize() overrides with no arguments
                if (!name().equals("finalize") || (mParameters.size() > 0)) {
                    Errors.error(Errors.CHANGED_THROWS, mInfo.position(),
                            "Method " + mInfo.qualifiedName() + " no longer throws exception "
                            + exec);
                    consistent = false;
                }
            }
        }
        
        for (String exec : mInfo.mExceptions) {
            // exclude 'throws' changes to finalize() overrides with no arguments
            if (!mExceptions.contains(exec)) {
                if (!name().equals("finalize") || (mParameters.size() > 0)) {
                    Errors.error(Errors.CHANGED_THROWS, mInfo.position(),
                            "Method " + mInfo.qualifiedName() + " added thrown exception "
                            + exec);
                    consistent = false;
                }
            }
        }
        
        return consistent;
    }
    
    public void addParameter(ParameterInfo pInfo) {
        mParameters.add(pInfo);
    }
    
    public void addException(String exc) {
        mExceptions.add(exc);
    }
    
    public String getParameterHash() {
        String hash = "";
        for (ParameterInfo pInfo : mParameters) {
            hash += ":" + pInfo.getType();
        }
        return hash;
    }
    
    public String getHashableName() {
        return qualifiedName() + getParameterHash();
    }
    
    public String getSignature() {
        return name() + getParameterHash();
    }
    
    public boolean isInBoth() {
        return mExistsInBoth;
    }

}
