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

public class MethodInfo extends MemberInfo
{
    public static final Comparator<MethodInfo> comparator = new Comparator<MethodInfo>() {
        public int compare(MethodInfo a, MethodInfo b) {
            return a.name().compareTo(b.name());
        }
    };
    
    private class InlineTags implements InheritedTags
    { 
        public TagInfo[] tags()
        {
            return comment().tags();
        }
        public InheritedTags inherited()
        {
            MethodInfo m = findOverriddenMethod(name(), signature());
            if (m != null) {
                return m.inlineTags();
            } else {
                return null;
            }
        }
    }
    
    private static void addInterfaces(ClassInfo[] ifaces, ArrayList<ClassInfo> queue)
    {
        for (ClassInfo i: ifaces) {
            queue.add(i);
        }
        for (ClassInfo i: ifaces) {
            addInterfaces(i.interfaces(), queue);
        }
    }

    // first looks for a superclass, and then does a breadth first search to
    // find the least far away match
    public MethodInfo findOverriddenMethod(String name, String signature)
    {
        if (mReturnType == null) {
            // ctor
            return null;
        }
        if (mOverriddenMethod != null) {
            return mOverriddenMethod;
        }

        ArrayList<ClassInfo> queue = new ArrayList<ClassInfo>();
        addInterfaces(containingClass().interfaces(), queue);
        for (ClassInfo iface: queue) {
            for (MethodInfo me: iface.methods()) {
                if (me.name().equals(name)
                        && me.signature().equals(signature)
                        && me.inlineTags().tags() != null
                        && me.inlineTags().tags().length > 0) {
                    return me;
                }
            }
        }
        return null;
    }
    
    private static void addRealInterfaces(ClassInfo[] ifaces, ArrayList<ClassInfo> queue)
    {
        for (ClassInfo i: ifaces) {
            queue.add(i);
            if (i.realSuperclass() != null &&  i.realSuperclass().isAbstract()) {
                queue.add(i.superclass());
            }
        }
        for (ClassInfo i: ifaces) {
            addInterfaces(i.realInterfaces(), queue);
        }
    }
    
    public MethodInfo findRealOverriddenMethod(String name, String signature, HashSet notStrippable) {
        if (mReturnType == null) {
        // ctor
        return null;
        }
        if (mOverriddenMethod != null) {
            return mOverriddenMethod;
        }

        ArrayList<ClassInfo> queue = new ArrayList<ClassInfo>();
        if (containingClass().realSuperclass() != null && 
            containingClass().realSuperclass().isAbstract()) {
            queue.add(containingClass());
        }
        addInterfaces(containingClass().realInterfaces(), queue);
        for (ClassInfo iface: queue) {
            for (MethodInfo me: iface.methods()) {
                if (me.name().equals(name)
                    && me.signature().equals(signature)
                    && me.inlineTags().tags() != null
                    && me.inlineTags().tags().length > 0
                    && notStrippable.contains(me.containingClass())) {
                return me;
                }
            }
        }
        return null;
    }
    
    public MethodInfo findSuperclassImplementation(HashSet notStrippable) {
        if (mReturnType == null) {
            // ctor
            return null;
        }
        if (mOverriddenMethod != null) {
            // Even if we're told outright that this was the overridden method, we want to
            // be conservative and ignore mismatches of parameter types -- they arise from
            // extending generic specializations, and we want to consider the derived-class
            // method to be a non-override.
            if (this.signature().equals(mOverriddenMethod.signature())) {
                return mOverriddenMethod;
            }
        }

        ArrayList<ClassInfo> queue = new ArrayList<ClassInfo>();
        if (containingClass().realSuperclass() != null && 
                containingClass().realSuperclass().isAbstract()) {
            queue.add(containingClass());
        }
        addInterfaces(containingClass().realInterfaces(), queue);
        for (ClassInfo iface: queue) {
            for (MethodInfo me: iface.methods()) {
                if (me.name().equals(this.name())
                        && me.signature().equals(this.signature())
                        && notStrippable.contains(me.containingClass())) {
                    return me;
                }
            }
        }
        return null;
    }
    
    public ClassInfo findRealOverriddenClass(String name, String signature) {
        if (mReturnType == null) {
        // ctor
        return null;
        }
        if (mOverriddenMethod != null) {
            return mOverriddenMethod.mRealContainingClass;
        }

        ArrayList<ClassInfo> queue = new ArrayList<ClassInfo>();
        if (containingClass().realSuperclass() != null && 
            containingClass().realSuperclass().isAbstract()) {
            queue.add(containingClass());
        }
        addInterfaces(containingClass().realInterfaces(), queue);
        for (ClassInfo iface: queue) {
            for (MethodInfo me: iface.methods()) {
                if (me.name().equals(name)
                    && me.signature().equals(signature)
                    && me.inlineTags().tags() != null
                    && me.inlineTags().tags().length > 0) {
                return iface;
                }
            }
        }
        return null;
    }

    private class FirstSentenceTags implements InheritedTags
    {
        public TagInfo[] tags()
        {
            return comment().briefTags();
        }
        public InheritedTags inherited()
        {
            MethodInfo m = findOverriddenMethod(name(), signature());
            if (m != null) {
                return m.firstSentenceTags();
            } else {
                return null;
            }
        }
    }
    
    private class ReturnTags implements InheritedTags {
        public TagInfo[] tags() {
            return comment().returnTags();
        }
        public InheritedTags inherited() {
            MethodInfo m = findOverriddenMethod(name(), signature());
            if (m != null) {
                return m.returnTags();
            } else {
                return null;
            }
        }
    }
    
    public boolean isDeprecated() {
        boolean deprecated = false;
        if (!mDeprecatedKnown) {
            boolean commentDeprecated = (comment().deprecatedTags().length > 0);
            boolean annotationDeprecated = false;
            for (AnnotationInstanceInfo annotation : annotations()) {
                if (annotation.type().qualifiedName().equals("java.lang.Deprecated")) {
                    annotationDeprecated = true;
                    break;
                }
            }

            if (commentDeprecated != annotationDeprecated) {
                Errors.error(Errors.DEPRECATION_MISMATCH, position(),
                        "Method " + mContainingClass.qualifiedName() + "." + name()
                        + ": @Deprecated annotation and @deprecated doc tag do not match");
            }

            mIsDeprecated = commentDeprecated | annotationDeprecated;
            mDeprecatedKnown = true;
        }
        return mIsDeprecated;
    }
    
    public TypeInfo[] getTypeParameters(){
        return mTypeParameters;
    }

    public MethodInfo cloneForClass(ClassInfo newContainingClass) {
        MethodInfo result =  new MethodInfo(getRawCommentText(), mTypeParameters,
                name(), signature(), newContainingClass, realContainingClass(),
                isPublic(), isProtected(), isPackagePrivate(), isPrivate(), isFinal(), isStatic(),
                isSynthetic(), mIsAbstract, mIsSynchronized, mIsNative, mIsAnnotationElement,
                kind(), mFlatSignature, mOverriddenMethod,
                mReturnType, mParameters, mThrownExceptions, position(), annotations());
        result.init(mDefaultAnnotationElementValue);
        return result;
    }

    public MethodInfo(String rawCommentText, TypeInfo[] typeParameters, String name,
                        String signature, ClassInfo containingClass, ClassInfo realContainingClass,
                        boolean isPublic, boolean isProtected,
                        boolean isPackagePrivate, boolean isPrivate,
                        boolean isFinal, boolean isStatic, boolean isSynthetic,
                        boolean isAbstract, boolean isSynchronized, boolean isNative,
                        boolean isAnnotationElement, String kind,
                        String flatSignature, MethodInfo overriddenMethod,
                        TypeInfo returnType, ParameterInfo[] parameters,
                        ClassInfo[] thrownExceptions, SourcePositionInfo position,
                        AnnotationInstanceInfo[] annotations)
    {
        // Explicitly coerce 'final' state of Java6-compiled enum values() method, to match
        // the Java5-emitted base API description.
        super(rawCommentText, name, signature, containingClass, realContainingClass,
                isPublic, isProtected, isPackagePrivate, isPrivate,
                ((name.equals("values") && containingClass.isEnum()) ? true : isFinal),
                isStatic, isSynthetic, kind, position, annotations);

        // The underlying MethodDoc for an interface's declared methods winds up being marked
        // non-abstract.  Correct that here by looking at the immediate-parent class, and marking
        // this method abstract if it is an unimplemented interface method. 
        if (containingClass.isInterface()) {
            isAbstract = true;
        }

        mReasonOpened = "0:0";
        mIsAnnotationElement = isAnnotationElement;
        mTypeParameters = typeParameters;
        mIsAbstract = isAbstract;
        mIsSynchronized = isSynchronized;
        mIsNative = isNative;
        mFlatSignature = flatSignature;
        mOverriddenMethod = overriddenMethod;
        mReturnType = returnType;
        mParameters = parameters;
        mThrownExceptions = thrownExceptions;
    }

    public void init(AnnotationValueInfo defaultAnnotationElementValue)
    {
        mDefaultAnnotationElementValue = defaultAnnotationElementValue;
    }

    public boolean isAbstract()
    {
        return mIsAbstract;
    }

    public boolean isSynchronized()
    {
        return mIsSynchronized;
    }

    public boolean isNative()
    {
        return mIsNative;
    }

    public String flatSignature()
    {
        return mFlatSignature;
    }

    public InheritedTags inlineTags()
    {
        return new InlineTags();
    }

    public InheritedTags firstSentenceTags()
    {
        return new FirstSentenceTags();
    }

    public InheritedTags returnTags() {
        return new ReturnTags();
    }

    public TypeInfo returnType()
    {
        return mReturnType;
    }

    public String prettySignature()
    {
        String s = "(";
        int N = mParameters.length;
        for (int i=0; i<N; i++) {
            ParameterInfo p = mParameters[i];
            TypeInfo t = p.type();
            if (t.isPrimitive()) {
                s += t.simpleTypeName();
            } else {
                s += t.asClassInfo().name();
            }
            if (i != N-1) {
                s += ',';
            }
        }
        s += ')';
        return s;
    }

    private boolean inList(ClassInfo item, ThrowsTagInfo[] list)
    {
        int len = list.length;
        String qn = item.qualifiedName();
        for (int i=0; i<len; i++) {
            ClassInfo ex = list[i].exception();
            if (ex != null && ex.qualifiedName().equals(qn)) {
                return true;
            }
        }
        return false;
    }

    public ThrowsTagInfo[] throwsTags()
    {
        if (mThrowsTags == null) {
            ThrowsTagInfo[] documented = comment().throwsTags();
            ArrayList<ThrowsTagInfo> rv = new ArrayList<ThrowsTagInfo>();

            int len = documented.length;
            for (int i=0; i<len; i++) {
                rv.add(documented[i]);
            }

            ClassInfo[] all = mThrownExceptions;
            len = all.length;
            for (int i=0; i<len; i++) {
                ClassInfo cl = all[i];
                if (documented == null || !inList(cl, documented)) {
                    rv.add(new ThrowsTagInfo("@throws", "@throws",
                                        cl.qualifiedName(), cl, "",
                                        containingClass(), position()));
                }
            }
            mThrowsTags = rv.toArray(new ThrowsTagInfo[rv.size()]);
        }
        return mThrowsTags;
    }

    private static int indexOfParam(String name, String[] list)
    {
        final int N = list.length;
        for (int i=0; i<N; i++) {
            if (name.equals(list[i])) {
                return i;
            }
        }
        return -1;
    }

    public ParamTagInfo[] paramTags()
    {
        if (mParamTags == null) {
            final int N = mParameters.length;

            String[] names = new String[N];
            String[] comments = new String[N];
            SourcePositionInfo[] positions = new SourcePositionInfo[N];

            // get the right names so we can handle our names being different from
            // our parent's names.
            for (int i=0; i<N; i++) {
                names[i] = mParameters[i].name();
                comments[i] = "";
                positions[i] = mParameters[i].position();
            }

            // gather our comments, and complain about misnamed @param tags
            for (ParamTagInfo tag: comment().paramTags()) {
                int index = indexOfParam(tag.parameterName(), names);
                if (index >= 0) {
                    comments[index] = tag.parameterComment();
                    positions[index] = tag.position();
                } else {
                    Errors.error(Errors.UNKNOWN_PARAM_TAG_NAME, tag.position(),
                            "@param tag with name that doesn't match the parameter list: '"
                            + tag.parameterName() + "'");
                }
            }
             
            // get our parent's tags to fill in the blanks
            MethodInfo overridden = this.findOverriddenMethod(name(), signature());
            if (overridden != null) {
                ParamTagInfo[] maternal = overridden.paramTags();
                for (int i=0; i<N; i++) {
                    if (comments[i].equals("")) {
                        comments[i] = maternal[i].parameterComment();
                        positions[i] = maternal[i].position();
                    }
                }
            }

            // construct the results, and cache them for next time
            mParamTags = new ParamTagInfo[N];
            for (int i=0; i<N; i++) {
                mParamTags[i] = new ParamTagInfo("@param", "@param", names[i] + " " + comments[i],
                        parent(), positions[i]);

                // while we're here, if we find any parameters that are still undocumented at this
                // point, complain. (this warning is off by default, because it's really, really
                // common; but, it's good to be able to enforce it)
                if (comments[i].equals("")) {
                    Errors.error(Errors.UNDOCUMENTED_PARAMETER, positions[i],
                            "Undocumented parameter '" + names[i] + "' on method '"
                            + name() + "'");
                }
            }
        }
        return mParamTags;
    }

    public SeeTagInfo[] seeTags()
    {
        SeeTagInfo[] result = comment().seeTags();
        if (result == null) {
            if (mOverriddenMethod != null) {
                result = mOverriddenMethod.seeTags();
            }
        }
        return result;
    }

    public TagInfo[] deprecatedTags()
    {
        TagInfo[] result = comment().deprecatedTags();
        if (result.length == 0) {
            if (comment().undeprecateTags().length == 0) {
                if (mOverriddenMethod != null) {
                    result = mOverriddenMethod.deprecatedTags();
                }
            }
        }
        return result;
    }

    public ParameterInfo[] parameters()
    {
        return mParameters;
    }
    

    public boolean matchesParams(String[] params, String[] dimensions)
    {
        if (mParamStrings == null) {
            ParameterInfo[] mine = mParameters;
            int len = mine.length;
            if (len != params.length) {
                return false;
            }
            for (int i=0; i<len; i++) {
                TypeInfo t = mine[i].type();
                if (!t.dimension().equals(dimensions[i])) {
                    return false;
                }
                String qn = t.qualifiedTypeName();
                String s = params[i];
                int slen = s.length();
                int qnlen = qn.length();
                if (!(qn.equals(s) ||
                        ((slen+1)<qnlen && qn.charAt(qnlen-slen-1)=='.'
                         && qn.endsWith(s)))) {
                    return false;
                }
            }
        }
        return true;
    }

    public void makeHDF(HDF data, String base)
    {
        data.setValue(base + ".kind", kind());
        data.setValue(base + ".name", name());
        data.setValue(base + ".href", htmlPage());
        data.setValue(base + ".anchor", anchor());

        if (mReturnType != null) {
            returnType().makeHDF(data, base + ".returnType", false, typeVariables());
            data.setValue(base + ".abstract", mIsAbstract ? "abstract" : "");
        }

        data.setValue(base + ".synchronized", mIsSynchronized ? "synchronized" : "");
        data.setValue(base + ".final", isFinal() ? "final" : "");
        data.setValue(base + ".static", isStatic() ? "static" : "");

        TagInfo.makeHDF(data, base + ".shortDescr", firstSentenceTags());
        TagInfo.makeHDF(data, base + ".descr", inlineTags());
        TagInfo.makeHDF(data, base + ".deprecated", deprecatedTags());
        TagInfo.makeHDF(data, base + ".seeAlso", seeTags());
        ParamTagInfo.makeHDF(data, base + ".paramTags", paramTags());
        AttrTagInfo.makeReferenceHDF(data, base + ".attrRefs", comment().attrTags());
        ThrowsTagInfo.makeHDF(data, base + ".throws", throwsTags());
        ParameterInfo.makeHDF(data, base + ".params", parameters(), isVarArgs(), typeVariables());
        if (isProtected()) {
            data.setValue(base + ".scope", "protected");
        }
        else if (isPublic()) {
            data.setValue(base + ".scope", "public");
        }
        TagInfo.makeHDF(data, base + ".returns", returnTags());

        if (mTypeParameters != null) {
            TypeInfo.makeHDF(data, base + ".generic.typeArguments", mTypeParameters, false);
        }
    }

    public HashSet<String> typeVariables()
    {
        HashSet<String> result = TypeInfo.typeVariables(mTypeParameters);
        ClassInfo cl = containingClass();
        while (cl != null) {
            TypeInfo[] types = cl.asTypeInfo().typeArguments();
            if (types != null) {
                TypeInfo.typeVariables(types, result);
            }
            cl = cl.containingClass();
        }
        return result;
    }

    public boolean isExecutable()
    {
        return true;
    }

    public ClassInfo[] thrownExceptions()
    {
        return mThrownExceptions;
    }

    public String typeArgumentsName(HashSet<String> typeVars)
    {
        if (mTypeParameters == null || mTypeParameters.length == 0) {
            return "";
        } else {
            return TypeInfo.typeArgumentsName(mTypeParameters, typeVars);
        }
    }

    public boolean isAnnotationElement()
    {
        return mIsAnnotationElement;
    }

    public AnnotationValueInfo defaultAnnotationElementValue()
    {
        return mDefaultAnnotationElementValue;
    }
    
    public void setVarargs(boolean set){
        mIsVarargs = set;
    }
    public boolean isVarArgs(){
      return mIsVarargs;
    }
    public String toString(){
      return this.name();
    }
    
    public void setReason(String reason) {
        mReasonOpened = reason;
    }
    
    public String getReason() {
        return mReasonOpened;
    }

    private String mFlatSignature;
    private MethodInfo mOverriddenMethod;
    private TypeInfo mReturnType;
    private boolean mIsAnnotationElement;
    private boolean mIsAbstract;
    private boolean mIsSynchronized;
    private boolean mIsNative;
    private boolean mIsVarargs;
    private boolean mDeprecatedKnown;
    private boolean mIsDeprecated;
    private ParameterInfo[] mParameters;
    private ClassInfo[] mThrownExceptions;
    private String[] mParamStrings;
    ThrowsTagInfo[] mThrowsTags;
    private ParamTagInfo[] mParamTags;
    private TypeInfo[] mTypeParameters;
    private AnnotationValueInfo mDefaultAnnotationElementValue;
    private String mReasonOpened;
}

