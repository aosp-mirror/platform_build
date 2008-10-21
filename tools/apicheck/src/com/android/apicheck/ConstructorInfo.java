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

public class ConstructorInfo implements AbstractMethodInfo {
    
    private String mName;
    private String mType;
    private boolean mIsStatic;
    private boolean mIsFinal;
    private String mDeprecated;
    private String mScope;
    private List<String> mExceptions;
    private List<ParameterInfo> mParameters;
    private boolean mExistsInBoth;
    private SourcePositionInfo mSourcePosition;
    private ClassInfo mClass;
    
    public ConstructorInfo(String name, String type, boolean isStatic, boolean isFinal,
                           String deprecated, String scope, SourcePositionInfo pos, ClassInfo clazz) {
        mName = name;
        mType = type;
        mIsStatic = isStatic;
        mIsFinal = isFinal;
        mDeprecated= deprecated;
        mScope = scope;
        mExistsInBoth = false;
        mExceptions = new ArrayList<String>();
        mParameters = new ArrayList<ParameterInfo>();
        mSourcePosition = pos;
        mClass = clazz;
    }
    
    public void addParameter(ParameterInfo pInfo) {
        mParameters.add(pInfo);
    }
    
    public void addException(String exec) {
        mExceptions.add(exec);
    }
    
    public String getHashableName() {
      String returnString = qualifiedName();
      for (ParameterInfo pInfo : mParameters) {
          returnString += ":" + pInfo.getType();
      }
      return returnString;
    }
    
    public boolean isInBoth() {
        return mExistsInBoth;
    }
    
    public SourcePositionInfo position() {
        return mSourcePosition;
    }
    
    public String name() {
        return mName;
    }
    
    public String qualifiedName() {
        String baseName = (mClass != null)
                ? (mClass.qualifiedName() + ".")
                : "";
        return baseName + name();
    }
    
    public boolean isConsistent(ConstructorInfo mInfo) {
      mInfo.mExistsInBoth = true;
      mExistsInBoth = true;
      boolean consistent = true;
      
      if (mIsFinal != mInfo.mIsFinal) {
          consistent = false;
          Errors.error(Errors.CHANGED_FINAL, mInfo.position(),
                  "Method " + mInfo.qualifiedName() + " has changed 'final' qualifier");
      }
      
      if (mIsStatic != mInfo.mIsStatic) {
          consistent = false;
          Errors.error(Errors.CHANGED_FINAL, mInfo.position(),
                  "Method " + mInfo.qualifiedName() + " has changed 'static' qualifier");
      }
     
      if (!mScope.equals(mInfo.mScope)) {
          consistent = false;
          Errors.error(Errors.CHANGED_SCOPE, mInfo.position(),
                  "Method " + mInfo.qualifiedName() + " changed scope from "
                  + mScope + " to " + mInfo.mScope);
      }
      
      for (String exec : mExceptions) {
          if (!mInfo.mExceptions.contains(exec)) {
              Errors.error(Errors.CHANGED_THROWS, mInfo.position(),
                      "Method " + mInfo.qualifiedName() + " no longer throws exception "
                      + exec);
              consistent = false;
          }
      }
      
      for (String exec : mInfo.mExceptions) {
          if (!mExceptions.contains(exec)) {
              Errors.error(Errors.CHANGED_THROWS, mInfo.position(),
                      "Method " + mInfo.qualifiedName() + " added thrown exception "
                      + exec);
            consistent = false;
          }
      }
      
      return consistent;
  }
    

}
