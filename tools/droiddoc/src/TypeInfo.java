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

import org.clearsilver.HDF;
import org.clearsilver.CS;
import java.util.*;
import java.io.*;

public class TypeInfo
{
    public TypeInfo(boolean isPrimitive, String dimension,
            String simpleTypeName, String qualifiedTypeName,
            ClassInfo cl)
    {
        mIsPrimitive = isPrimitive;
        mDimension = dimension;
        mSimpleTypeName = simpleTypeName;
        mQualifiedTypeName = qualifiedTypeName;
        mClass = cl;
    }

    public ClassInfo asClassInfo()
    {
        return mClass;
    }

    public boolean isPrimitive()
    {
        return mIsPrimitive;
    }

    public String dimension()
    {
        return mDimension;
    }

    public String simpleTypeName()
    {
        return mSimpleTypeName;
    }

    public String qualifiedTypeName()
    {
        return mQualifiedTypeName;
    }

    public String fullName()
    {
        if (mFullName != null) {
            return mFullName;
        } else {
            return fullName(new HashSet());
        }
    }

    public static String typeArgumentsName(TypeInfo[] args, HashSet<String> typeVars)
    {
        String result = "<";
        for (int i=0; i<args.length; i++) {
            result += args[i].fullName(typeVars);
            if (i != args.length-1) {
                result += ", ";
            }
        }
        result += ">";
        return result;
    }

    public String fullName(HashSet<String> typeVars)
    {
        mFullName = fullNameNoDimension(typeVars) + mDimension;
        return mFullName;
    }

    public String fullNameNoDimension(HashSet<String> typeVars)
    {
        String fullName = null;
        if (mIsTypeVariable) {
            if (typeVars.contains(mQualifiedTypeName)) {
                // don't recurse forever with the parameters.  This handles
                // Enum<K extends Enum<K>>
                return mQualifiedTypeName;
            }
            typeVars.add(mQualifiedTypeName);
        }
/*
        if (fullName != null) {
            return fullName;
        }
*/
        fullName = mQualifiedTypeName;
        if (mTypeArguments != null && mTypeArguments.length > 0) {
            fullName += typeArgumentsName(mTypeArguments, typeVars);
        }
        else if (mSuperBounds != null && mSuperBounds.length > 0) {
            fullName += " super " + mSuperBounds[0].fullName(typeVars);
            for (int i=1; i<mSuperBounds.length; i++) {
                fullName += " & " + mSuperBounds[i].fullName(typeVars);
            }
        }
        else if (mExtendsBounds != null && mExtendsBounds.length > 0) {
            fullName += " extends " + mExtendsBounds[0].fullName(typeVars);
            for (int i=1; i<mExtendsBounds.length; i++) {
                fullName += " & " + mExtendsBounds[i].fullName(typeVars);
            }
        }
        return fullName;
    }

    public TypeInfo[] typeArguments()
    {
        return mTypeArguments;
    }

    public void makeHDF(HDF data, String base)
    {
        makeHDFRecursive(data, base, false, false, new HashSet<String>());
    }

    public void makeQualifiedHDF(HDF data, String base)
    {
        makeHDFRecursive(data, base, true, false, new HashSet<String>());
    }

    public void makeHDF(HDF data, String base, boolean isLastVararg,
            HashSet<String> typeVariables)
    {
        makeHDFRecursive(data, base, false, isLastVararg, typeVariables);
    }

    public void makeQualifiedHDF(HDF data, String base, HashSet<String> typeVariables)
    {
        makeHDFRecursive(data, base, true, false, typeVariables);
    }

    private void makeHDFRecursive(HDF data, String base, boolean qualified,
            boolean isLastVararg, HashSet<String> typeVars)
    {
        String label = qualified ? qualifiedTypeName() : simpleTypeName();
        label += (isLastVararg) ? "..." : dimension();
        data.setValue(base + ".label", label);
        ClassInfo cl = asClassInfo();
        if (mIsTypeVariable || mIsWildcard) {
            // could link to an @param tag on the class to describe this
            // but for now, just don't make it a link
        }
        else if (!isPrimitive() && cl != null && cl.isIncluded()) {
            data.setValue(base + ".link", cl.htmlPage());
            data.setValue(base + ".since", cl.getSince());
        }

        if (mIsTypeVariable) {
            if (typeVars.contains(qualifiedTypeName())) {
                // don't recurse forever with the parameters.  This handles
                // Enum<K extends Enum<K>>
                return;
            }
            typeVars.add(qualifiedTypeName());
        }
        if (mTypeArguments != null) {
            TypeInfo.makeHDF(data, base + ".typeArguments", mTypeArguments, qualified, typeVars);
        }
        if (mSuperBounds != null) {
            TypeInfo.makeHDF(data, base + ".superBounds", mSuperBounds, qualified, typeVars);
        }
        if (mExtendsBounds != null) {
            TypeInfo.makeHDF(data, base + ".extendsBounds", mExtendsBounds, qualified, typeVars);
        }
    }

    public static void makeHDF(HDF data, String base, TypeInfo[] types, boolean qualified,
            HashSet<String> typeVariables)
    {
        final int N = types.length;
        for (int i=0; i<N; i++) {
            types[i].makeHDFRecursive(data, base + "." + i, qualified, false, typeVariables);
        }
    }

    public static void makeHDF(HDF data, String base, TypeInfo[] types, boolean qualified)
    {
        makeHDF(data, base, types, qualified, new HashSet<String>());
    }

    void setTypeArguments(TypeInfo[] args)
    {
        mTypeArguments = args;
    }

    void setBounds(TypeInfo[] superBounds, TypeInfo[] extendsBounds)
    {
        mSuperBounds = superBounds;
        mExtendsBounds = extendsBounds;
    }

    void setIsTypeVariable(boolean b)
    {
        mIsTypeVariable = b;
    }

    void setIsWildcard(boolean b)
    {
        mIsWildcard = b;
    }

    static HashSet<String> typeVariables(TypeInfo[] params)
    {
        return typeVariables(params, new HashSet());
    }

    static HashSet<String> typeVariables(TypeInfo[] params, HashSet<String> result)
    {
        for (TypeInfo t: params) {
            if (t.mIsTypeVariable) {
                result.add(t.mQualifiedTypeName);
            }
        }
        return result;
    }


    public boolean isTypeVariable()
    {
        return mIsTypeVariable;
    }

    public String defaultValue() {
        if (mIsPrimitive) {
            if ("boolean".equals(mSimpleTypeName)) {
                return "false";
            } else {
                return "0";
            }
        } else {
            return "null";
        }
    }

    @Override
    public String toString(){
      String returnString = "";
      returnString += "Primitive?: " + mIsPrimitive + " TypeVariable?: " +
      mIsTypeVariable + " Wildcard?: " + mIsWildcard + " Dimension: " + mDimension
      + " QualifedTypeName: " + mQualifiedTypeName;

      if (mTypeArguments != null){
        returnString += "\nTypeArguments: ";
        for (TypeInfo tA : mTypeArguments){
          returnString += tA.qualifiedTypeName() + "(" + tA + ") ";
        }
      }
      if (mSuperBounds != null){
        returnString += "\nSuperBounds: ";
        for (TypeInfo tA : mSuperBounds){
          returnString += tA.qualifiedTypeName() + "(" + tA + ") ";
        }
      }
      if (mExtendsBounds != null){
        returnString += "\nExtendsBounds: ";
        for (TypeInfo tA : mExtendsBounds){
          returnString += tA.qualifiedTypeName() + "(" + tA + ") ";
        }
      }
      return returnString;
    }

    private boolean mIsPrimitive;
    private boolean mIsTypeVariable;
    private boolean mIsWildcard;
    private String mDimension;
    private String mSimpleTypeName;
    private String mQualifiedTypeName;
    private ClassInfo mClass;
    private TypeInfo[] mTypeArguments;
    private TypeInfo[] mSuperBounds;
    private TypeInfo[] mExtendsBounds;
    private String mFullName;
}
