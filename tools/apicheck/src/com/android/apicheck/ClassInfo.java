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

public class ClassInfo {
    private String mName;
    private String mSuperClassName;
    private boolean mIsInterface;
    private boolean mIsAbstract;
    private boolean mIsStatic;
    private boolean mIsFinal;
    private String mDeprecated;
    private String mScope;
    private List<String> mInterfaceNames;
    private List<ClassInfo> mInterfaces;
    private HashMap<String, MethodInfo> mMethods;
    private HashMap<String, FieldInfo> mFields;
    private HashMap<String, ConstructorInfo> mConstructors;
    private boolean mExistsInBoth;
    private PackageInfo mPackage;
    private SourcePositionInfo mSourcePosition;
    private ClassInfo mSuperClass;
    private ClassInfo mParentClass;

    public ClassInfo(String name, PackageInfo pack, String superClass, boolean isInterface,
                     boolean isAbstract, boolean isStatic, boolean isFinal, String deprecated,
                     String visibility, SourcePositionInfo source, ClassInfo parent) {
        mName = name;
        mPackage = pack;
        mSuperClassName = superClass;
        mIsInterface = isInterface;
        mIsAbstract = isAbstract;
        mIsStatic = isStatic;
        mIsFinal = isFinal;
        mDeprecated = deprecated;
        mScope = visibility;
        mInterfaceNames = new ArrayList<String>();
        mInterfaces = new ArrayList<ClassInfo>();
        mMethods = new HashMap<String, MethodInfo>();
        mFields = new HashMap<String, FieldInfo>();
        mConstructors = new HashMap<String, ConstructorInfo>();
        mExistsInBoth = false;
        mSourcePosition = source;
        mParentClass = parent;
    }

    public String name() {
        return mName;
    }

    public String qualifiedName() {
        String parentQName = (mParentClass != null)
                ? (mParentClass.qualifiedName() + ".")
                : "";
        return mPackage.name() + "." + parentQName + name();
    }

    public String superclassName() {
        return mSuperClassName;
    }
    
    public SourcePositionInfo position() {
        return mSourcePosition;
    }

    public boolean isInterface() {
        return mIsInterface;
    }

    public boolean isFinal() {
        return mIsFinal;
    }
    
    // Find a superclass implementation of the given method.
    public static MethodInfo overriddenMethod(MethodInfo candidate, ClassInfo newClassObj) {
        if (newClassObj == null) {
            return null;
        }
        for (MethodInfo mi : newClassObj.mMethods.values()) {
            if (mi.matches(candidate)) {
                // found it
                return mi;
            }
        }

        // not found here. recursively search ancestors
        return ClassInfo.overriddenMethod(candidate, newClassObj.mSuperClass);
    }
    
    // Find a superinterface declaration of the given method.
    public static MethodInfo interfaceMethod(MethodInfo candidate, ClassInfo newClassObj) {
        if (newClassObj == null) {
            return null;
        }
        for (ClassInfo interfaceInfo : newClassObj.mInterfaces) {
            for (MethodInfo mi : interfaceInfo.mMethods.values()) {
                if (mi.matches(candidate)) {
                    return mi;
                }
            }
        }
        return ClassInfo.interfaceMethod(candidate, newClassObj.mSuperClass);
    }

    public boolean isConsistent(ClassInfo cl) {
        cl.mExistsInBoth = true;
        mExistsInBoth = true;
        boolean consistent = true;

        if (isInterface() != cl.isInterface()) {
            Errors.error(Errors.CHANGED_CLASS, cl.position(),
                    "Class " + cl.qualifiedName()
                    + " changed class/interface declaration");
            consistent = false;
        }
        for (String iface : mInterfaceNames) {
            if (!implementsInterface(cl, iface)) {
                Errors.error(Errors.REMOVED_INTERFACE, cl.position(),
                        "Class " + qualifiedName() + " no longer implements " + iface);
            }
        }
        for (String iface : cl.mInterfaceNames) {
          if (!mInterfaceNames.contains(iface)) {
              Errors.error(Errors.ADDED_INTERFACE, cl.position(),
                      "Added interface " + iface + " to class "
                      + qualifiedName());
              consistent = false;
            }
        }
        
        for (MethodInfo mInfo : mMethods.values()) {
            if (cl.mMethods.containsKey(mInfo.getHashableName())) {
                if (!mInfo.isConsistent(cl.mMethods.get(mInfo.getHashableName()))) {
                    consistent = false;
                }
            } else {
                /* This class formerly provided this method directly, and now does not.
                 * Check our ancestry to see if there's an inherited version that still
                 * fulfills the API requirement.
                 */
                MethodInfo mi = ClassInfo.overriddenMethod(mInfo, cl);
                if (mi == null) {
                    mi = ClassInfo.interfaceMethod(mInfo, cl);
                }
                if (mi == null) {
                    Errors.error(Errors.REMOVED_METHOD, mInfo.position(),
                            "Removed public method " + mInfo.qualifiedName());
                    consistent = false;
                }
            }
        }
        for (MethodInfo mInfo : cl.mMethods.values()) {
            if (!mInfo.isInBoth()) {
                /* Similarly to the above, do not fail if this "new" method is
                 * really an override of an existing superclass method.
                 */
                MethodInfo mi = ClassInfo.overriddenMethod(mInfo, cl);
                if (mi == null) {
                    Errors.error(Errors.ADDED_METHOD, mInfo.position(),
                            "Added public method " + mInfo.qualifiedName());
                    consistent = false;
                }
            }
        }
        
        for (ConstructorInfo mInfo : mConstructors.values()) {
          if (cl.mConstructors.containsKey(mInfo.getHashableName())) {
              if (!mInfo.isConsistent(cl.mConstructors.get(mInfo.getHashableName()))) {
                  consistent = false;
              }
          } else {
              Errors.error(Errors.REMOVED_METHOD, mInfo.position(),
                      "Removed public constructor " + mInfo.prettySignature());
              consistent = false;
          }
        }
        for (ConstructorInfo mInfo : cl.mConstructors.values()) {
            if (!mInfo.isInBoth()) {
                Errors.error(Errors.ADDED_METHOD, mInfo.position(),
                        "Added public constructor " + mInfo.prettySignature());
                consistent = false;
            }
        }
        
        for (FieldInfo mInfo : mFields.values()) {
          if (cl.mFields.containsKey(mInfo.name())) {
              if (!mInfo.isConsistent(cl.mFields.get(mInfo.name()))) {
                  consistent = false;
              }
          } else {
              Errors.error(Errors.REMOVED_FIELD, mInfo.position(),
                      "Removed field " + mInfo.qualifiedName());
              consistent = false;
          }
        }
        for (FieldInfo mInfo : cl.mFields.values()) {
            if (!mInfo.isInBoth()) {
                Errors.error(Errors.ADDED_FIELD, mInfo.position(),
                        "Added public field " + mInfo.qualifiedName());
                consistent = false;
            }
        }
        
        if (mIsAbstract != cl.mIsAbstract) {
            consistent = false;
            Errors.error(Errors.CHANGED_ABSTRACT, cl.position(),
                    "Class " + cl.qualifiedName() + " changed abstract qualifier");
        }
      
        if (mIsFinal != cl.mIsFinal) {
            consistent = false;
            Errors.error(Errors.CHANGED_FINAL, cl.position(),
                    "Class " + cl.qualifiedName() + " changed final qualifier");
        }
      
        if (mIsStatic != cl.mIsStatic) {
            consistent = false;
            Errors.error(Errors.CHANGED_STATIC, cl.position(),
                    "Class " + cl.qualifiedName() + " changed static qualifier");
        }
     
        if (!mScope.equals(cl.mScope)) {
            consistent = false;
            Errors.error(Errors.CHANGED_SCOPE, cl.position(),
                    "Class " + cl.qualifiedName() + " scope changed from "
                    + mScope + " to " + cl.mScope);
        }
        
        if (!mDeprecated.equals(cl.mDeprecated)) {
            consistent = false;
            Errors.error(Errors.CHANGED_DEPRECATED, cl.position(),
                    "Class " + cl.qualifiedName() + " has changed deprecation state");
        }
        
        if (mSuperClassName != null) {
            if (cl.mSuperClassName == null || !mSuperClassName.equals(cl.mSuperClassName)) {
                consistent = false;
                Errors.error(Errors.CHANGED_SUPERCLASS, cl.position(),
                        "Class " + qualifiedName() + " superclass changed from "
                        + mSuperClassName + " to " + cl.mSuperClassName);
            }
        } else if (cl.mSuperClassName != null) {
            consistent = false;
            Errors.error(Errors.CHANGED_SUPERCLASS, cl.position(),
                    "Class " + qualifiedName() + " superclass changed from "
                    + "null to " + cl.mSuperClassName);
        }
        
        return consistent;
    }

    /**
     * Returns true if {@code cl} implements the interface {@code iface} either
     * by either being that interface, implementing that interface or extending
     * a type that implements the interface.
     */
    private boolean implementsInterface(ClassInfo cl, String iface) {
        if (cl.qualifiedName().equals(iface)) {
            return true;
        }
        for (ClassInfo clImplements : cl.mInterfaces) {
            if (implementsInterface(clImplements, iface)) {
                return true;
            }
        }
        if (cl.mSuperClass != null && implementsInterface(cl.mSuperClass, iface)) {
            return true;
        }
        return false;
    }

    public void resolveInterfaces(ApiInfo apiInfo) {
        for (String interfaceName : mInterfaceNames) {
            mInterfaces.add(apiInfo.findClass(interfaceName));
        }
    }
    
    public void addInterface(String name) {
        mInterfaceNames.add(name);
    }
    
    public void addMethod(MethodInfo mInfo) {
        mMethods.put(mInfo.getHashableName(), mInfo);
    }
    
    public void addConstructor(ConstructorInfo cInfo) {
        mConstructors.put(cInfo.getHashableName(), cInfo);
        
    }
    
    public void addField(FieldInfo fInfo) {
        mFields.put(fInfo.name(), fInfo);
      
    }
    
    public void setSuperClass(ClassInfo superclass) {
        mSuperClass = superclass;
    }
    
    public boolean isInBoth() {
        return mExistsInBoth;
    }

    public Map<String, ConstructorInfo> allConstructors() {
        return mConstructors;
    }

    public Map<String, FieldInfo> allFields() {
        return mFields;
    }

    public Map<String, MethodInfo> allMethods() {
        return mMethods;
    }

    /**
     * Returns the class hierarchy for this class, starting with this class.
     */
    public Iterable<ClassInfo> hierarchy() {
        List<ClassInfo> result = new ArrayList<ClassInfo>(4);
        for (ClassInfo c  = this; c != null; c = c.mSuperClass) {
            result.add(c);
        }
        return result;
    }
}
