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

public class FieldInfo {
  
    private String mName;
    private String mType;
    private boolean mIsTransient;
    private boolean mIsVolatile;
    private String mValue;
    private boolean mIsStatic;
    private boolean mIsFinal;
    private String mDeprecated;
    private String mScope;
    private boolean mExistsInBoth;
    private SourcePositionInfo mSourcePosition;
    private ClassInfo mClass;
    
    public FieldInfo (String name, String type, boolean isTransient, boolean isVolatile,
                       String value, boolean isStatic, boolean isFinal, String deprecated,
                       String scope, SourcePositionInfo source, ClassInfo parent) {
        mName = name;
        mType = type;
        mIsTransient = isTransient;
        mIsVolatile = isVolatile;
        mValue = value;
        mIsStatic = isStatic;
        mIsFinal = isFinal;
        mDeprecated = deprecated;
        mScope = scope;
        mExistsInBoth = false;
        mSourcePosition = source;
        mClass = parent;
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
        String parentQName = (mClass != null)
                ? (mClass.qualifiedName() + ".")
                : "";
        return parentQName + name();
    }
    
    // Check the declared value with a typed comparison, not a string comparison,
    // to accommodate toolchains with different fp -> string conversions.
    public boolean valueEquals(FieldInfo other) {
        // Type mismatch means nonequal, as does a null/non-null mismatch
        if (!mType.equals(other.mType)
                || ((mValue == null) != (other.mValue == null))) {
            return false;
        }

        // Null values are considered equal
        if (mValue == null) {
            return true;
        }

        // Floating point gets an implementation-type comparison; all others just use the string
        // If float/double parse fails, fall back to string comparison -- it means that it's a
        // canonical droiddoc-generated constant expression that represents a NaN.
        try {
            if (mType.equals("float")) {
                float val = Float.parseFloat(mValue);
                float otherVal = Float.parseFloat(other.mValue);
                return (val == otherVal);
            } else if (mType.equals("double")) {
                double val = Double.parseDouble(mValue);
                double otherVal = Double.parseDouble(other.mValue);
                return (val == otherVal);
            }
        } catch (NumberFormatException e) {
            // fall through
        }
        
        return mValue.equals(other.mValue);
    }

    public boolean isConsistent(FieldInfo fInfo) {
      fInfo.mExistsInBoth = true;
      mExistsInBoth = true;
      boolean consistent = true;
      if (!mType.equals(fInfo.mType)) {
          Errors.error(Errors.CHANGED_TYPE, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed type");
          consistent = false;
      }

      if (!this.valueEquals(fInfo)) {
          Errors.error(Errors.CHANGED_VALUE, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed value from "
                  + mValue + " to " + fInfo.mValue);
          consistent = false;
      }
      
      if (!mScope.equals(fInfo.mScope)) {
          Errors.error(Errors.CHANGED_SCOPE, fInfo.position(),
                  "Method " + fInfo.qualifiedName() + " changed scope from "
                  + mScope + " to " + fInfo.mScope);
          consistent = false;
      }
      
      if (mIsStatic != fInfo.mIsStatic) {
          Errors.error(Errors.CHANGED_STATIC, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed 'static' qualifier");
          consistent = false;
      }
      
      if (mIsFinal != fInfo.mIsFinal) {
          Errors.error(Errors.CHANGED_FINAL, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed 'final' qualifier");
          consistent = false;
      }
      
      if (mIsTransient != fInfo.mIsTransient) {
          Errors.error(Errors.CHANGED_TRANSIENT, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed 'transient' qualifier");
          consistent = false;
      }
      
      if (mIsVolatile != fInfo.mIsVolatile) {
          Errors.error(Errors.CHANGED_VOLATILE, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed 'volatile' qualifier");
          consistent = false;
      }
      
      if (!mDeprecated.equals(fInfo.mDeprecated)) {
          Errors.error(Errors.CHANGED_DEPRECATED, fInfo.position(),
                  "Field " + fInfo.qualifiedName() + " has changed deprecation state");
          consistent = false;
      }
      
      return consistent;
    }

}
