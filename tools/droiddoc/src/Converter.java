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

import com.sun.javadoc.*;
import com.sun.tools.doclets.*;
import org.clearsilver.HDF;
import org.clearsilver.CS;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;

public class Converter
{
    private static RootDoc root;

    public static void makeInfo(RootDoc r)
    {
        root = r;

        int N, i;

        // create the objects
        ClassDoc[] classDocs = r.classes();
        N = classDocs.length;
        for (i=0; i<N; i++) {
            Converter.obtainClass(classDocs[i]);
        }
        ArrayList<ClassInfo> classesNeedingInit2 = new ArrayList<ClassInfo>();
        // fill in the fields that reference other classes
        while (mClassesNeedingInit.size() > 0) {
            i = mClassesNeedingInit.size()-1;
            ClassNeedingInit clni = mClassesNeedingInit.get(i);
            mClassesNeedingInit.remove(i);

            initClass(clni.c, clni.cl);
            classesNeedingInit2.add(clni.cl);
        }
        mClassesNeedingInit = null;
        for (ClassInfo cl: classesNeedingInit2) {
            cl.init2();
        }

        finishAnnotationValueInit();

        // fill in the "root" stuff
        mRootClasses = Converter.convertClasses(r.classes());
    }

    private static ClassInfo[] mRootClasses;
    public static ClassInfo[] rootClasses()
    {
        return mRootClasses;
    }

    public static ClassInfo[] allClasses() {
        return (ClassInfo[])mClasses.all();
    }

    private static void initClass(ClassDoc c, ClassInfo cl)
    {
        MethodDoc[] annotationElements;
        if (c instanceof AnnotationTypeDoc) {
            annotationElements = ((AnnotationTypeDoc)c).elements();
        } else {
            annotationElements = new MethodDoc[0];
        }
        cl.init(Converter.obtainType(c),
                Converter.convertClasses(c.interfaces()),
                Converter.convertTypes(c.interfaceTypes()),
                Converter.convertClasses(c.innerClasses()),
                Converter.convertMethods(c.constructors(false)),
                Converter.convertMethods(c.methods(false)),
                Converter.convertMethods(annotationElements),
                Converter.convertFields(c.fields(false)),
                Converter.convertFields(c.enumConstants()),
                Converter.obtainPackage(c.containingPackage()),
                Converter.obtainClass(c.containingClass()),
                Converter.obtainClass(c.superclass()),
                Converter.obtainType(c.superclassType()),
                Converter.convertAnnotationInstances(c.annotations())
                );
          cl.setHiddenMethods(Converter.getHiddenMethods(c.methods(false)));
          cl.setNonWrittenConstructors(Converter.convertNonWrittenConstructors(c.constructors(false)));
          cl.init3(Converter.convertTypes(c.typeParameters()), Converter.convertClasses(c.innerClasses(false)));
    }

    public static ClassInfo obtainClass(String className)
    {
        return Converter.obtainClass(root.classNamed(className));
    }

    public static PackageInfo obtainPackage(String packageName)
    {
        return Converter.obtainPackage(root.packageNamed(packageName));
    }

    private static TagInfo convertTag(Tag tag)
    {
        return new TextTagInfo(tag.name(), tag.kind(), tag.text(),
                                Converter.convertSourcePosition(tag.position()));
    }

    private static ThrowsTagInfo convertThrowsTag(ThrowsTag tag,
                                                ContainerInfo base)
    {
        return new ThrowsTagInfo(tag.name(), tag.text(), tag.kind(),
                              Converter.obtainClass(tag.exception()),
                              tag.exceptionComment(), base,
                              Converter.convertSourcePosition(tag.position()));
    }

    private static ParamTagInfo convertParamTag(ParamTag tag,
                                                ContainerInfo base)
    {
        return new ParamTagInfo(tag.name(), tag.kind(), tag.text(),
                              tag.isTypeParameter(), tag.parameterComment(),
                              tag.parameterName(),
                              base,
                              Converter.convertSourcePosition(tag.position()));
    }

    private static SeeTagInfo convertSeeTag(SeeTag tag, ContainerInfo base)
    {
        return new SeeTagInfo(tag.name(), tag.kind(), tag.text(), base,
                              Converter.convertSourcePosition(tag.position()));
    }

    private static SourcePositionInfo convertSourcePosition(SourcePosition sp)
    {
        if (sp == null) {
            return null;
        }
        return new SourcePositionInfo(sp.file().toString(), sp.line(),
                                        sp.column());
    }

    public static TagInfo[] convertTags(Tag[] tags, ContainerInfo base)
    {
        int len = tags.length;
        TagInfo[] out = new TagInfo[len];
        for (int i=0; i<len; i++) {
            Tag t = tags[i];
            /*
            System.out.println("Tag name='" + t.name() + "' kind='"
                    + t.kind() + "'");
            */
            if (t instanceof SeeTag) {
                out[i] = Converter.convertSeeTag((SeeTag)t, base);
            }
            else if (t instanceof ThrowsTag) {
                out[i] = Converter.convertThrowsTag((ThrowsTag)t, base);
            }
            else if (t instanceof ParamTag) {
                out[i] = Converter.convertParamTag((ParamTag)t, base);
            }
            else {
                out[i] = Converter.convertTag(t);
            }
        }
        return out;
    }

    public static ClassInfo[] convertClasses(ClassDoc[] classes)
    {
        if (classes == null) return null;
        int N = classes.length;
        ClassInfo[] result = new ClassInfo[N];
        for (int i=0; i<N; i++) {
            result[i] = Converter.obtainClass(classes[i]);
        }
        return result;
    }

    private static ParameterInfo convertParameter(Parameter p, SourcePosition pos)
    {
        if (p == null) return null;
        ParameterInfo pi = new ParameterInfo(p.name(), p.typeName(),
                Converter.obtainType(p.type()),
                Converter.convertSourcePosition(pos));
        return pi;
    }

    private static ParameterInfo[] convertParameters(Parameter[] p, MemberDoc m)
    {
        SourcePosition pos = m.position();
        int len = p.length;
        ParameterInfo[] q = new ParameterInfo[len];
        for (int i=0; i<len; i++) {
            q[i] = Converter.convertParameter(p[i], pos);
        }
        return q;
    }

    private static TypeInfo[] convertTypes(Type[] p)
    {
        if (p == null) return null;
        int len = p.length;
        TypeInfo[] q = new TypeInfo[len];
        for (int i=0; i<len; i++) {
            q[i] = Converter.obtainType(p[i]);
        }
        return q;
    }

    private Converter()
    {
    }

    private static class ClassNeedingInit
    {
        ClassNeedingInit(ClassDoc c, ClassInfo cl)
        {
            this.c = c;
            this.cl = cl;
        }
        ClassDoc c;
        ClassInfo cl;
    };
    private static ArrayList<ClassNeedingInit> mClassesNeedingInit
                                            = new ArrayList<ClassNeedingInit>();

    static ClassInfo obtainClass(ClassDoc o)
    {
        return (ClassInfo)mClasses.obtain(o);
    }
    private static Cache mClasses = new Cache()
    {
        protected Object make(Object o)
        {
            ClassDoc c = (ClassDoc)o;
            ClassInfo cl = new ClassInfo(
                    c,
                    c.getRawCommentText(),
                    Converter.convertSourcePosition(c.position()),
                    c.isPublic(),
                    c.isProtected(),
                    c.isPackagePrivate(),
                    c.isPrivate(),
                    c.isStatic(),
                    c.isInterface(),
                    c.isAbstract(),
                    c.isOrdinaryClass(),
                    c.isException(),
                    c.isError(),
                    c.isEnum(),
                    (c instanceof AnnotationTypeDoc),
                    c.isFinal(),
                    c.isIncluded(),
                    c.name(),
                    c.qualifiedName(),
                    c.qualifiedTypeName(),
                    c.isPrimitive());
            if (mClassesNeedingInit != null) {
                mClassesNeedingInit.add(new ClassNeedingInit(c, cl));
            }
            return cl;
        }
        protected void made(Object o, Object r)
        {
            if (mClassesNeedingInit == null) {
                initClass((ClassDoc)o, (ClassInfo)r);
                ((ClassInfo)r).init2();
            }
        } 
        ClassInfo[] all()
        {
            return (ClassInfo[])mCache.values().toArray(new ClassInfo[mCache.size()]);
        }
    };
    
    private static MethodInfo[] getHiddenMethods(MethodDoc[] methods){
      if (methods == null) return null;
      ArrayList<MethodInfo> out = new ArrayList<MethodInfo>();
      int N = methods.length;
      for (int i=0; i<N; i++) {
          MethodInfo m = Converter.obtainMethod(methods[i]);
          //System.out.println(m.toString() + ": ");
          //for (TypeInfo ti : m.getTypeParameters()){
            //  if (ti.asClassInfo() != null){
                //System.out.println(" " +ti.asClassInfo().toString());
              //} else {
                //System.out.println(" null");
              //}
            //}
          if (m.isHidden()) {
              out.add(m);
          }
      }
      return out.toArray(new MethodInfo[out.size()]);
    }

    /**
     * Convert MethodDoc[] into MethodInfo[].  Also filters according
     * to the -private, -public option, because the filtering doesn't seem
     * to be working in the ClassDoc.constructors(boolean) call.
     */
    private static MethodInfo[] convertMethods(MethodDoc[] methods)
    {
        if (methods == null) return null;
        ArrayList<MethodInfo> out = new ArrayList<MethodInfo>();
        int N = methods.length;
        for (int i=0; i<N; i++) {
            MethodInfo m = Converter.obtainMethod(methods[i]);
            //System.out.println(m.toString() + ": ");
            //for (TypeInfo ti : m.getTypeParameters()){
              //  if (ti.asClassInfo() != null){
                  //System.out.println(" " +ti.asClassInfo().toString());
                //} else {
                  //System.out.println(" null");
                //}
              //}
            if (m.checkLevel()) {
                out.add(m);
            }
        }
        return out.toArray(new MethodInfo[out.size()]);
    }

    private static MethodInfo[] convertMethods(ConstructorDoc[] methods)
    {
        if (methods == null) return null;
        ArrayList<MethodInfo> out = new ArrayList<MethodInfo>();
        int N = methods.length;
        for (int i=0; i<N; i++) {
            MethodInfo m = Converter.obtainMethod(methods[i]);
            if (m.checkLevel()) {
                out.add(m);
            }
        }
        return out.toArray(new MethodInfo[out.size()]);
    }
    
    private static MethodInfo[] convertNonWrittenConstructors(ConstructorDoc[] methods)
    {
        if (methods == null) return null;
        ArrayList<MethodInfo> out = new ArrayList<MethodInfo>();
        int N = methods.length;
        for (int i=0; i<N; i++) {
            MethodInfo m = Converter.obtainMethod(methods[i]);
            if (!m.checkLevel()) {
                out.add(m);
            }
        }
        return out.toArray(new MethodInfo[out.size()]);
    }

    private static MethodInfo obtainMethod(MethodDoc o)
    {
        return (MethodInfo)mMethods.obtain(o);
    }
    private static MethodInfo obtainMethod(ConstructorDoc o)
    {
        return (MethodInfo)mMethods.obtain(o);
    }
    private static Cache mMethods = new Cache()
    {
        protected Object make(Object o)
        {
            if (o instanceof AnnotationTypeElementDoc) {
                AnnotationTypeElementDoc m = (AnnotationTypeElementDoc)o;
                MethodInfo result = new MethodInfo(
                                m.getRawCommentText(),
                                Converter.convertTypes(m.typeParameters()),
                                m.name(), m.signature(), 
                                Converter.obtainClass(m.containingClass()),
                                Converter.obtainClass(m.containingClass()),
                                m.isPublic(), m.isProtected(),
                                m.isPackagePrivate(), m.isPrivate(),
                                m.isFinal(), m.isStatic(), m.isSynthetic(),
                                m.isAbstract(), m.isSynchronized(), m.isNative(), true,
                                "annotationElement",
                                m.flatSignature(),
                                Converter.obtainMethod(m.overriddenMethod()),
                                Converter.obtainType(m.returnType()),
                                Converter.convertParameters(m.parameters(), m),
                                Converter.convertClasses(m.thrownExceptions()),
                                Converter.convertSourcePosition(m.position()),
                                Converter.convertAnnotationInstances(m.annotations())
                            );
                result.setVarargs(m.isVarArgs());
                result.init(Converter.obtainAnnotationValue(m.defaultValue(), result));
                return result;
            }
            else if (o instanceof MethodDoc) {
                MethodDoc m = (MethodDoc)o;
                MethodInfo result = new MethodInfo(
                                m.getRawCommentText(),
                                Converter.convertTypes(m.typeParameters()),
                                m.name(), m.signature(), 
                                Converter.obtainClass(m.containingClass()),
                                Converter.obtainClass(m.containingClass()),
                                m.isPublic(), m.isProtected(),
                                m.isPackagePrivate(), m.isPrivate(),
                                m.isFinal(), m.isStatic(), m.isSynthetic(),
                                m.isAbstract(), m.isSynchronized(), m.isNative(), false,
                                "method",
                                m.flatSignature(),
                                Converter.obtainMethod(m.overriddenMethod()),
                                Converter.obtainType(m.returnType()),
                                Converter.convertParameters(m.parameters(), m),
                                Converter.convertClasses(m.thrownExceptions()),
                                Converter.convertSourcePosition(m.position()),
                                Converter.convertAnnotationInstances(m.annotations())
                           );
                result.setVarargs(m.isVarArgs());
                result.init(null);
                return result;
            }
            else {
                ConstructorDoc m = (ConstructorDoc)o;
                MethodInfo result = new MethodInfo(
                                m.getRawCommentText(),
                                Converter.convertTypes(m.typeParameters()),
                                m.name(), m.signature(), 
                                Converter.obtainClass(m.containingClass()),
                                Converter.obtainClass(m.containingClass()),
                                m.isPublic(), m.isProtected(),
                                m.isPackagePrivate(), m.isPrivate(),
                                m.isFinal(), m.isStatic(), m.isSynthetic(),
                                false, m.isSynchronized(), m.isNative(), false,
                                "constructor",
                                m.flatSignature(),
                                null,
                                null,
                                Converter.convertParameters(m.parameters(), m),
                                Converter.convertClasses(m.thrownExceptions()),
                                Converter.convertSourcePosition(m.position()),
                                Converter.convertAnnotationInstances(m.annotations())
                            );
                result.setVarargs(m.isVarArgs());
                result.init(null);
                return result;
            }
        }
    };


    private static FieldInfo[] convertFields(FieldDoc[] fields)
    {
        if (fields == null) return null;
        ArrayList<FieldInfo> out = new ArrayList<FieldInfo>();
        int N = fields.length;
        for (int i=0; i<N; i++) {
            FieldInfo f = Converter.obtainField(fields[i]);
            if (f.checkLevel()) {
                out.add(f);
            }
        }
        return out.toArray(new FieldInfo[out.size()]);
    }

    private static FieldInfo obtainField(FieldDoc o)
    {
        return (FieldInfo)mFields.obtain(o);
    }
    private static FieldInfo obtainField(ConstructorDoc o)
    {
        return (FieldInfo)mFields.obtain(o);
    }
    private static Cache mFields = new Cache()
    {
        protected Object make(Object o)
        {
            FieldDoc f = (FieldDoc)o;
            return new FieldInfo(f.name(),
                            Converter.obtainClass(f.containingClass()),
                            Converter.obtainClass(f.containingClass()),
                            f.isPublic(), f.isProtected(),
                            f.isPackagePrivate(), f.isPrivate(),
                            f.isFinal(), f.isStatic(), f.isTransient(), f.isVolatile(),
                            f.isSynthetic(),
                            Converter.obtainType(f.type()),
                            f.getRawCommentText(), f.constantValue(),
                            Converter.convertSourcePosition(f.position()),
                            Converter.convertAnnotationInstances(f.annotations())
                        );
        }
    };

    private static PackageInfo obtainPackage(PackageDoc o)
    {
        return (PackageInfo)mPackagees.obtain(o);
    }
    private static Cache mPackagees = new Cache()
    {
        protected Object make(Object o)
        {
            PackageDoc p = (PackageDoc)o;
            return new PackageInfo(p, p.name(),
                    Converter.convertSourcePosition(p.position()));
        }
    };

    private static TypeInfo obtainType(Type o)
    {
        return (TypeInfo)mTypes.obtain(o);
    }
    private static Cache mTypes = new Cache()
    {
       protected Object make(Object o)
       {
           Type t = (Type)o;
           String simpleTypeName;
           if (t instanceof ClassDoc) {
               simpleTypeName = ((ClassDoc)t).name();
           } else {
               simpleTypeName = t.simpleTypeName();
           }
           TypeInfo ti = new TypeInfo(t.isPrimitive(), t.dimension(),
                   simpleTypeName, t.qualifiedTypeName(),
                   Converter.obtainClass(t.asClassDoc()));
           return ti;
       }
        protected void made(Object o, Object r)
        {
            Type t = (Type)o;
            TypeInfo ti = (TypeInfo)r;
            if (t.asParameterizedType() != null) {
                ti.setTypeArguments(Converter.convertTypes(
                            t.asParameterizedType().typeArguments()));
            }
            else if (t instanceof ClassDoc) {
                ti.setTypeArguments(Converter.convertTypes(((ClassDoc)t).typeParameters()));
            }
            else if (t.asTypeVariable() != null) {
                ti.setBounds(null, Converter.convertTypes((t.asTypeVariable().bounds())));
                ti.setIsTypeVariable(true);
            }
            else if (t.asWildcardType() != null) {
                ti.setIsWildcard(true);
                ti.setBounds(Converter.convertTypes(t.asWildcardType().superBounds()),
                             Converter.convertTypes(t.asWildcardType().extendsBounds()));
            }
        }
        protected Object keyFor(Object o)
        {  
            Type t = (Type)o;
            String keyString = o.getClass().getName() + "/" + o.toString() + "/";
            if (t.asParameterizedType() != null){
              keyString += t.asParameterizedType().toString() +"/";
              if (t.asParameterizedType().typeArguments() != null){
              for(Type ty : t.asParameterizedType().typeArguments()){
                keyString += ty.toString() + "/";
              }
              }
            }else{
              keyString += "NoParameterizedType//";
            }
            if (t.asTypeVariable() != null){
              keyString += t.asTypeVariable().toString() +"/";
              if (t.asTypeVariable().bounds() != null){
              for(Type ty : t.asTypeVariable().bounds()){
                keyString += ty.toString() + "/";
              }
              }
            }else{
              keyString += "NoTypeVariable//";
            }
            if (t.asWildcardType() != null){
              keyString += t.asWildcardType().toString() +"/";
              if (t.asWildcardType().superBounds() != null){
              for(Type ty : t.asWildcardType().superBounds()){
                keyString += ty.toString() + "/";
              }
              }
              if (t.asWildcardType().extendsBounds() != null){
                for(Type ty : t.asWildcardType().extendsBounds()){
                  keyString += ty.toString() + "/";
                }
                }
            }else{
              keyString += "NoWildCardType//";
            }
            
            
            
            return keyString;
        }
    };
    


    private static MemberInfo obtainMember(MemberDoc o)
    {
        return (MemberInfo)mMembers.obtain(o);
    }
    private static Cache mMembers = new Cache()
    {
        protected Object make(Object o)
        {
            if (o instanceof MethodDoc) {
                return Converter.obtainMethod((MethodDoc)o);
            }
            else if (o instanceof ConstructorDoc) {
                return Converter.obtainMethod((ConstructorDoc)o);
            }
            else if (o instanceof FieldDoc) {
                return Converter.obtainField((FieldDoc)o);
            }
            else {
                return null;
            }
        }
    };

    private static AnnotationInstanceInfo[] convertAnnotationInstances(AnnotationDesc[] orig)
    {
        int len = orig.length;
        AnnotationInstanceInfo[] out = new AnnotationInstanceInfo[len];
        for (int i=0; i<len; i++) {
            out[i] = Converter.obtainAnnotationInstance(orig[i]);
        }
        return out;
    }


    private static AnnotationInstanceInfo obtainAnnotationInstance(AnnotationDesc o)
    {
        return (AnnotationInstanceInfo)mAnnotationInstances.obtain(o);
    }
    private static Cache mAnnotationInstances = new Cache()
    {
        protected Object make(Object o)
        {
            AnnotationDesc a = (AnnotationDesc)o;
            ClassInfo annotationType = Converter.obtainClass(a.annotationType());
            AnnotationDesc.ElementValuePair[] ev = a.elementValues();
            AnnotationValueInfo[] elementValues = new AnnotationValueInfo[ev.length];
            for (int i=0; i<ev.length; i++) {
                elementValues[i] = obtainAnnotationValue(ev[i].value(),
                                            Converter.obtainMethod(ev[i].element()));
            }
            return new AnnotationInstanceInfo(annotationType, elementValues);
        }
    };


    private abstract static class Cache
    {
        void put(Object key, Object value)
        {
            mCache.put(key, value);
        }
        Object obtain(Object o)
        {
            if (o == null ) {
                return null;
            }
            Object k = keyFor(o);
            Object r = mCache.get(k);
            if (r == null) {
                r = make(o);
                mCache.put(k, r);
                made(o, r);
            }
            return r;
        }
        protected HashMap<Object,Object> mCache = new HashMap<Object,Object>();
        protected abstract Object make(Object o);
        protected void made(Object o, Object r)
        {
        }
        protected Object keyFor(Object o) { return o; }
        Object[] all() { return null; }
    }

    // annotation values
    private static HashMap<AnnotationValue,AnnotationValueInfo> mAnnotationValues = new HashMap();
    private static HashSet<AnnotationValue> mAnnotationValuesNeedingInit = new HashSet();

    private static AnnotationValueInfo obtainAnnotationValue(AnnotationValue o, MethodInfo element)
    {
        if (o == null) {
            return null;
        }
        AnnotationValueInfo v = mAnnotationValues.get(o);
        if (v != null) return v;
        v = new AnnotationValueInfo(element);
        mAnnotationValues.put(o, v);
        if (mAnnotationValuesNeedingInit != null) {
            mAnnotationValuesNeedingInit.add(o);
        } else {
            initAnnotationValue(o, v);
        }
        return v;
    }

    private static void initAnnotationValue(AnnotationValue o, AnnotationValueInfo v) {
        Object orig = o.value();
        Object converted;
        if (orig instanceof Type) {
            // class literal
            converted = Converter.obtainType((Type)orig);
        }
        else if (orig instanceof FieldDoc) {
            // enum constant
            converted = Converter.obtainField((FieldDoc)orig);
        }
        else if (orig instanceof AnnotationDesc) {
            // annotation instance
            converted = Converter.obtainAnnotationInstance((AnnotationDesc)orig);
        }
        else if (orig instanceof AnnotationValue[]) {
            AnnotationValue[] old = (AnnotationValue[])orig;
            AnnotationValueInfo[] array = new AnnotationValueInfo[old.length];
            for (int i=0; i<array.length; i++) {
                array[i] = Converter.obtainAnnotationValue(old[i], null);
            }
            converted = array;
        }
        else {
            converted = orig;
        }
        v.init(converted);
    }

    private static void finishAnnotationValueInit()
    {
        int depth = 0;
        while (mAnnotationValuesNeedingInit.size() > 0) {
            HashSet<AnnotationValue> set = mAnnotationValuesNeedingInit;
            mAnnotationValuesNeedingInit = new HashSet();
            for (AnnotationValue o: set) {
                AnnotationValueInfo v = mAnnotationValues.get(o);
                initAnnotationValue(o, v);
            }
            depth++;
        }
        mAnnotationValuesNeedingInit = null;
    }
}
