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

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Set;
import java.util.Comparator;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintStream;

public class Stubs {
    private static HashSet<ClassInfo> notStrippable;
    public static void writeStubs(String stubsDir, Boolean writeXML, String xmlFile,
            HashSet<String> stubPackages) {
        // figure out which classes we need
        notStrippable = new HashSet();
        ClassInfo[] all = Converter.allClasses();
        File  xml = new File(xmlFile);
        xml.getParentFile().mkdirs();
        PrintStream xmlWriter = null;
        if (writeXML) {
            try {
                xmlWriter = new PrintStream(xml);
            } catch (FileNotFoundException e) {
                Errors.error(Errors.IO_ERROR, new SourcePositionInfo(xmlFile, 0, 0),
                        "Cannot open file for write.");
            }
        }
        // If a class is public or protected, not hidden, and marked as included,
        // then we can't strip it
        for (ClassInfo cl: all) {
            if (cl.checkLevel() && cl.isIncluded()) {
                cantStripThis(cl, notStrippable, "0:0");
            }
        }

        // complain about anything that looks includeable but is not supposed to
        // be written, e.g. hidden things
        for (ClassInfo cl: notStrippable) {
            if (!cl.isHidden()) {
                MethodInfo[] methods = cl.selfMethods();
                for (MethodInfo m: methods) {
                    if (m.isHidden()) {
                        Errors.error(Errors.UNAVAILABLE_SYMBOL,
                                m.position(), "Reference to hidden method "
                                + m.name());
                    } else if (m.isDeprecated()) {
                        // don't bother reporting deprecated methods
                        // unless they are public
                        Errors.error(Errors.DEPRECATED,
                                m.position(), "Method "
                                + cl.qualifiedName() + "." + m.name()
                                + " is deprecated");
                    }

                    ClassInfo returnClass = m.returnType().asClassInfo();
                    if (returnClass != null && returnClass.isHidden()) {
                        Errors.error(Errors.UNAVAILABLE_SYMBOL, m.position(),
                                "Method " + cl.qualifiedName() + "." + m.name()
                                + " returns unavailable type " + returnClass.name());
                    }

                    ParameterInfo[] params = m.parameters();
                    for (ParameterInfo p: params) {
                        TypeInfo t = p.type();
                        if (!t.isPrimitive()) {
                            if (t.asClassInfo().isHidden()) {
                                Errors.error(Errors.UNAVAILABLE_SYMBOL,
                                        m.position(), "Parameter of hidden type "
                                        + t.fullName() + " in "
                                        + cl.qualifiedName() + "." + m.name() + "()");
                            }
                        }
                    }
                }

                // annotations are handled like methods
                methods = cl.annotationElements();
                for (MethodInfo m: methods) {
                    if (m.isHidden()) {
                        Errors.error(Errors.UNAVAILABLE_SYMBOL,
                                m.position(), "Reference to hidden annotation "
                                + m.name());
                    }

                    ClassInfo returnClass = m.returnType().asClassInfo();
                    if (returnClass != null && returnClass.isHidden()) {
                        Errors.error(Errors.UNAVAILABLE_SYMBOL,
                                m.position(), "Annotation '" + m.name()
                                + "' returns unavailable type " + returnClass.name());
                    }

                    ParameterInfo[] params = m.parameters();
                    for (ParameterInfo p: params) {
                        TypeInfo t = p.type();
                        if (!t.isPrimitive()) {
                            if (t.asClassInfo().isHidden()) {
                                Errors.error(Errors.UNAVAILABLE_SYMBOL,
                                        p.position(), "Reference to unavailable annotation class "
                                        + t.fullName());
                            }
                        }
                    }
                }
            } else if (cl.isDeprecated()) {
                // not hidden, but deprecated
                Errors.error(Errors.DEPRECATED,
                        cl.position(), "Class " + cl.qualifiedName()
                        + " is deprecated");
            }
        }

        // write out the stubs
        HashMap<PackageInfo, List<ClassInfo>> packages = new HashMap<PackageInfo, List<ClassInfo>>();
        for (ClassInfo cl: notStrippable) {
            if (!cl.isDocOnly()) {
                if (stubPackages == null || stubPackages.contains(cl.containingPackage().name())) {
                    writeClassFile(stubsDir, cl);
                    if (packages.containsKey(cl.containingPackage())) {
                        packages.get(cl.containingPackage()).add(cl);
                    } else {
                        ArrayList<ClassInfo> classes = new ArrayList<ClassInfo>();
                        classes.add(cl);
                        packages.put(cl.containingPackage(), classes);
                    }
                }
            }
        }

        // write out the XML
        if (writeXML && xmlWriter != null) {
            writeXML(xmlWriter, packages, notStrippable);
        }

        if (xmlWriter != null) {
            xmlWriter.close();
        }

    }

    public static void cantStripThis(ClassInfo cl, HashSet<ClassInfo> notStrippable, String why) {

      if (!notStrippable.add(cl)) {
        // slight optimization: if it already contains cl, it already contains
        // all of cl's parents
          return;
      }
      cl.setReasonIncluded(why);

      // cant strip annotations
      /*if (cl.annotations() != null){
          for (AnnotationInstanceInfo ai : cl.annotations()){
              if (ai.type() != null){
                  cantStripThis(ai.type(), notStrippable, "1:" + cl.qualifiedName());
              }
          }
      }*/
      // cant strip any public fields or their generics
      if (cl.allSelfFields() != null){
          for (FieldInfo fInfo : cl.allSelfFields()){
              if (fInfo.type() != null){
                  if (fInfo.type().asClassInfo() != null){
                      cantStripThis(fInfo.type().asClassInfo(), notStrippable,
                          "2:" + cl.qualifiedName());
                  }
                  if (fInfo.type().typeArguments() != null){
                      for (TypeInfo tTypeInfo : fInfo.type().typeArguments()){
                          if (tTypeInfo.asClassInfo() != null){
                              cantStripThis(tTypeInfo.asClassInfo(), notStrippable,
                                  "3:" + cl.qualifiedName());
                          }
                      }
                  }
              }
          }
      }
      //cant strip any of the type's generics
      if (cl.asTypeInfo() != null){
          if (cl.asTypeInfo().typeArguments() != null){
              for (TypeInfo tInfo : cl.asTypeInfo().typeArguments()){
                  if (tInfo.asClassInfo() != null){
                      cantStripThis(tInfo.asClassInfo(), notStrippable, "4:" + cl.qualifiedName());
                  }
              }
          }
      }
      //cant strip any of the annotation elements
      //cantStripThis(cl.annotationElements(), notStrippable);
      // take care of methods
      cantStripThis(cl.allSelfMethods(), notStrippable);
      cantStripThis(cl.allConstructors(), notStrippable);
      // blow the outer class open if this is an inner class
      if(cl.containingClass() != null){
          cantStripThis(cl.containingClass(), notStrippable, "5:" + cl.qualifiedName());
      }
      // blow open super class and interfaces
     ClassInfo supr = cl.realSuperclass();
      if (supr != null) {
          if (supr.isHidden()) {
              // cl is a public class declared as extending a hidden superclass.
              // this is not a desired practice but it's happened, so we deal
              // with it by stripping off the superclass relation for purposes of
              // generating the doc & stub information, and proceeding normally.
              cl.init(cl.asTypeInfo(), cl.realInterfaces(), cl.realInterfaceTypes(),
                      cl.innerClasses(), cl.allConstructors(), cl.allSelfMethods(),
                      cl.annotationElements(), cl.allSelfFields(), cl.enumConstants(),
                      cl.containingPackage(), cl.containingClass(),
                      null, null, cl.annotations());
              Errors.error(Errors.HIDDEN_SUPERCLASS,
                      cl.position(), "Public class " + cl.qualifiedName()
                      + " stripped of unavailable superclass "
                      + supr.qualifiedName());
          } else {
              cantStripThis(supr, notStrippable, "6:" + cl.realSuperclass().name()
                      + cl.qualifiedName());
          }
      }
    }

    private static void cantStripThis(MethodInfo[] mInfos , HashSet<ClassInfo> notStrippable) {
      //for each method, blow open the parameters, throws and return types.  also blow open their generics
      if (mInfos != null){
          for (MethodInfo mInfo : mInfos){
              if (mInfo.getTypeParameters() != null){
                  for (TypeInfo tInfo : mInfo.getTypeParameters()){
                      if (tInfo.asClassInfo() != null){
                          cantStripThis(tInfo.asClassInfo(), notStrippable, "8:" +
                                        mInfo.realContainingClass().qualifiedName() + ":" +
                                        mInfo.name());
                      }
                  }
              }
              if (mInfo.parameters() != null){
                  for (ParameterInfo pInfo : mInfo.parameters()){
                      if (pInfo.type() != null && pInfo.type().asClassInfo() != null){
                          cantStripThis(pInfo.type().asClassInfo(), notStrippable,
                                        "9:"+  mInfo.realContainingClass().qualifiedName()
                                        + ":" + mInfo.name());
                          if (pInfo.type().typeArguments() != null){
                              for (TypeInfo tInfoType : pInfo.type().typeArguments()){
                                  if (tInfoType.asClassInfo() != null){
                                      ClassInfo tcl = tInfoType.asClassInfo();
                                      if (tcl.isHidden()) {
                                          Errors.error(Errors.UNAVAILABLE_SYMBOL, mInfo.position(),
                                                  "Parameter of hidden type "
                                                  + tInfoType.fullName() + " in "
                                                  + mInfo.containingClass().qualifiedName()
                                                  + '.' + mInfo.name() + "()");
                                      } else {
                                          cantStripThis(tcl, notStrippable,
                                                  "10:" +
                                                  mInfo.realContainingClass().qualifiedName() + ":" +
                                                  mInfo.name());
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
              for (ClassInfo thrown : mInfo.thrownExceptions()){
                  cantStripThis(thrown, notStrippable, "11:" +
                                mInfo.realContainingClass().qualifiedName()
                                +":" + mInfo.name());
              }
              if (mInfo.returnType() != null && mInfo.returnType().asClassInfo() != null){
                  cantStripThis(mInfo.returnType().asClassInfo(), notStrippable,
                                "12:" + mInfo.realContainingClass().qualifiedName() +
                                ":" + mInfo.name());
                  if (mInfo.returnType().typeArguments() != null){
                      for (TypeInfo tyInfo: mInfo.returnType().typeArguments() ){
                          if (tyInfo.asClassInfo() != null){
                              cantStripThis(tyInfo.asClassInfo(), notStrippable,
                                            "13:" +
                                            mInfo.realContainingClass().qualifiedName()
                                            + ":" + mInfo.name());
                          }
                      }
                  }
              }
          }
      }
    }

    static String javaFileName(ClassInfo cl) {
        String dir = "";
        PackageInfo pkg = cl.containingPackage();
        if (pkg != null) {
            dir = pkg.name();
            dir = dir.replace('.', '/') + '/';
        }
        return dir + cl.name() + ".java";
    }

    static void writeClassFile(String stubsDir, ClassInfo cl) {
        // inner classes are written by their containing class
        if (cl.containingClass() != null) {
            return;
        }

        // Work around the bogus "Array" class we invent for
        // Arrays.copyOf's Class<? extends T[]> newType parameter. (http://b/2715505)
        if (cl.containingPackage() != null && cl.containingPackage().name().equals("")) {
            return;
        }

        String filename = stubsDir + '/' + javaFileName(cl);
        File file = new File(filename);
        ClearPage.ensureDirectory(file);

        PrintStream stream = null;
        try {
            stream = new PrintStream(file);
            writeClassFile(stream, cl);
        }
        catch (FileNotFoundException e) {
            System.err.println("error writing file: " + filename);
        }
        finally {
            if (stream != null) {
                stream.close();
            }
        }
    }

    static void writeClassFile(PrintStream stream, ClassInfo cl) {
        PackageInfo pkg = cl.containingPackage();
        if (pkg != null) {
            stream.println("package " + pkg.name() + ";");
        }
        writeClass(stream, cl);
    }

    static void writeClass(PrintStream stream, ClassInfo cl) {
        writeAnnotations(stream, cl.annotations());

        stream.print(DroidDoc.scope(cl) + " ");
        if (cl.isAbstract() && !cl.isAnnotation() && !cl.isInterface()) {
            stream.print("abstract ");
        }
        if (cl.isStatic()){
            stream.print("static ");
        }
        if (cl.isFinal() && !cl.isEnum()) {
            stream.print("final ");
        }
        if (false) {
            stream.print("strictfp ");
        }

        HashSet<String> classDeclTypeVars = new HashSet();
        String leafName = cl.asTypeInfo().fullName(classDeclTypeVars);
        int bracket = leafName.indexOf('<');
        if (bracket < 0) bracket = leafName.length() - 1;
        int period = leafName.lastIndexOf('.', bracket);
        if (period < 0) period = -1;
        leafName = leafName.substring(period+1);

        String kind = cl.kind();
        stream.println(kind + " " + leafName);

        TypeInfo base = cl.superclassType();

        if (!"enum".equals(kind)) {
            if (base != null && !"java.lang.Object".equals(base.qualifiedTypeName())) {
                stream.println("  extends " + base.fullName(classDeclTypeVars));
            }
        }

        TypeInfo[] interfaces = cl.realInterfaceTypes();
        List<TypeInfo> usedInterfaces = new ArrayList<TypeInfo>();
        for (TypeInfo iface : interfaces) {
            if (notStrippable.contains(iface.asClassInfo())
                    && !iface.asClassInfo().isDocOnly()) {
                usedInterfaces.add(iface);
            }
        }
        if (usedInterfaces.size() > 0 && !cl.isAnnotation()) {
            // can java annotations extend other ones?
            if (cl.isInterface() || cl.isAnnotation()) {
                stream.print("  extends ");
            } else {
                stream.print("  implements ");
            }
            String comma = "";
            for (TypeInfo iface: usedInterfaces) {
                stream.print(comma + iface.fullName(classDeclTypeVars));
                comma = ", ";
            }
            stream.println();
        }

        stream.println("{");

        FieldInfo[] enumConstants = cl.enumConstants();
        int N = enumConstants.length;
        for (int i=0; i<N; i++) {
            FieldInfo field = enumConstants[i];
            if (!field.constantLiteralValue().equals("null")){
            stream.println(field.name() + "(" + field.constantLiteralValue()
                    + (i==N-1 ? ");" : "),"));
            }else{
              stream.println(field.name() + "(" + (i==N-1 ? ");" : "),"));
            }
        }

        for (ClassInfo inner: cl.getRealInnerClasses()) {
            if (notStrippable.contains(inner)
                    && !inner.isDocOnly()){
                writeClass(stream, inner);
            }
        }


        for (MethodInfo method: cl.constructors()) {
            if (!method.isDocOnly()) {
                writeMethod(stream, method, true);
            }
        }

        boolean fieldNeedsInitialization = false;
        boolean staticFieldNeedsInitialization = false;
        for (FieldInfo field: cl.allSelfFields()) {
            if (!field.isDocOnly()) {
                if (!field.isStatic() && field.isFinal() && !fieldIsInitialized(field)) {
                    fieldNeedsInitialization = true;
                }
                if (field.isStatic() && field.isFinal() && !fieldIsInitialized(field)) {
                    staticFieldNeedsInitialization = true;
                }
            }
        }

        // The compiler includes a default public constructor that calls the super classes
        // default constructor in the case where there are no written constructors.
        // So, if we hide all the constructors, java may put in a constructor
        // that calls a nonexistent super class constructor.  So, if there are no constructors,
        // and the super class doesn't have a default constructor, write in a private constructor
        // that works.  TODO -- we generate this as protected, but we really should generate
        // it as private unless it also exists in the real code.
        if ((cl.constructors().length == 0 && (cl.getNonWrittenConstructors().length != 0
                    || fieldNeedsInitialization))
                && !cl.isAnnotation()
                && !cl.isInterface()
                && !cl.isEnum() ) {
            //Errors.error(Errors.HIDDEN_CONSTRUCTOR,
            //             cl.position(), "No constructors " +
            //            "found and superclass has no parameterless constructor.  A constructor " +
            //            "that calls an appropriate superclass constructor " +
            //            "was automatically written to stubs.\n");
            stream.println(cl.leafName()
                    + "() { " + superCtorCall(cl,null)
                    + "throw new" + " RuntimeException(\"Stub!\"); }");
        }

        for (MethodInfo method: cl.allSelfMethods()) {
            if (cl.isEnum()) {
                if (("values".equals(method.name())
                            && "()".equals(method.signature()))
                    || ("valueOf".equals(method.name())
                            && "(java.lang.String)".equals(method.signature()))) {
                    // skip these two methods on enums, because they're synthetic,
                    // although for some reason javadoc doesn't mark them as synthetic,
                    // maybe because they still want them documented
                    continue;
                }
            }
            if (!method.isDocOnly()) {
                writeMethod(stream, method, false);
            }
        }
        //Write all methods that are hidden, but override abstract methods or interface methods.
        //These can't be hidden.
        for (MethodInfo method : cl.getHiddenMethods()){
            MethodInfo overriddenMethod = method.findRealOverriddenMethod(method.name(), method.signature(), notStrippable);
            ClassInfo classContainingMethod = method.findRealOverriddenClass(method.name(),
                                                                             method.signature());
            if (overriddenMethod != null && !overriddenMethod.isHidden()
                && !overriddenMethod.isDocOnly() &&
                (overriddenMethod.isAbstract() ||
                overriddenMethod.containingClass().isInterface())) {
                method.setReason("1:" + classContainingMethod.qualifiedName());
                cl.addMethod(method);
                writeMethod(stream, method, false);
            }
        }

        for (MethodInfo element: cl.annotationElements()) {
            if (!element.isDocOnly()) {
                writeAnnotationElement(stream, element);
            }
        }

        for (FieldInfo field: cl.allSelfFields()) {
            if (!field.isDocOnly()) {
                writeField(stream, field);
            }
        }

        if (staticFieldNeedsInitialization) {
            stream.print("static { ");
            for (FieldInfo field: cl.allSelfFields()) {
                if (!field.isDocOnly() && field.isStatic() && field.isFinal()
                        && !fieldIsInitialized(field) && field.constantValue() == null) {
                    stream.print(field.name() + " = " + field.type().defaultValue()
                            + "; ");
                }
            }
            stream.println("}");
        }

        stream.println("}");
    }


    static void writeMethod(PrintStream stream, MethodInfo method, boolean isConstructor) {
        String comma;

        stream.print(DroidDoc.scope(method) + " ");
        if (method.isStatic()) {
            stream.print("static ");
        }
        if (method.isFinal()) {
            stream.print("final ");
        }
        if (method.isAbstract()) {
            stream.print("abstract ");
        }
        if (method.isSynchronized()) {
            stream.print("synchronized ");
        }
        if (method.isNative()) {
            stream.print("native ");
        }
        if (false /*method.isStictFP()*/) {
            stream.print("strictfp ");
        }

        stream.print(method.typeArgumentsName(new HashSet()) + " ");

        if (!isConstructor) {
            stream.print(method.returnType().fullName(method.typeVariables()) + " ");
        }
        String n = method.name();
        int pos = n.lastIndexOf('.');
        if (pos >= 0) {
            n = n.substring(pos + 1);
        }
        stream.print(n + "(");
        comma = "";
        int count = 1;
        int size = method.parameters().length;
        for (ParameterInfo param: method.parameters()) {
            stream.print(comma + fullParameterTypeName(method, param.type(), count == size)
                    + " " + param.name());
            comma = ", ";
            count++;
        }
        stream.print(")");

        comma = "";
        if (method.thrownExceptions().length > 0) {
            stream.print(" throws ");
            for (ClassInfo thrown: method.thrownExceptions()) {
                stream.print(comma + thrown.qualifiedName());
                comma = ", ";
            }
        }
        if (method.isAbstract() || method.isNative() || method.containingClass().isInterface()) {
            stream.println(";");
        } else {
            stream.print(" { ");
            if (isConstructor) {
                stream.print(superCtorCall(method.containingClass(), method.thrownExceptions()));
            }
            stream.println("throw new RuntimeException(\"Stub!\"); }");
        }
    }

    static void writeField(PrintStream stream, FieldInfo field) {
        stream.print(DroidDoc.scope(field) + " ");
        if (field.isStatic()) {
            stream.print("static ");
        }
        if (field.isFinal()) {
            stream.print("final ");
        }
        if (field.isTransient()) {
            stream.print("transient ");
        }
        if (field.isVolatile()) {
            stream.print("volatile ");
        }

        stream.print(field.type().fullName());
        stream.print(" ");
        stream.print(field.name());

        if (fieldIsInitialized(field)) {
            stream.print(" = " + field.constantLiteralValue());
        }

        stream.println(";");
    }

    static boolean fieldIsInitialized(FieldInfo field) {
        return (field.isFinal() && field.constantValue() != null)
                || !field.type().dimension().equals("")
                || field.containingClass().isInterface();
    }

    // Returns 'true' if the method is an @Override of a visible parent
    // method implementation, and thus does not affect the API.
    static boolean methodIsOverride(MethodInfo mi) {
        // Abstract/static/final methods are always listed in the API description
        if (mi.isAbstract() || mi.isStatic() || mi.isFinal()) {
            return false;
        }

        // Find any relevant ancestor declaration and inspect it
        MethodInfo om = mi.findSuperclassImplementation(notStrippable);
        if (om != null) {
            // Visibility mismatch is an API change, so check for it
            if (mi.mIsPrivate == om.mIsPrivate
                    && mi.mIsPublic == om.mIsPublic
                    && mi.mIsProtected == om.mIsProtected) {
                // Look only for overrides of an ancestor class implementation,
                // not of e.g. an abstract or interface method declaration
                if (!om.isAbstract()) {
                    // If the parent is hidden, we can't rely on it to provide
                    // the API
                    if (!om.isHidden()) {
                        // If the only "override" turns out to be in our own class
                        // (which sometimes happens in concrete subclasses of
                        // abstract base classes), it's not really an override
                        if (!mi.mContainingClass.equals(om.mContainingClass)) {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    static boolean canCallMethod(ClassInfo from, MethodInfo m) {
        if (m.isPublic() || m.isProtected()) {
            return true;
        }
        if (m.isPackagePrivate()) {
            String fromPkg = from.containingPackage().name();
            String pkg = m.containingClass().containingPackage().name();
            if (fromPkg.equals(pkg)) {
                return true;
            }
        }
        return false;
    }

    // call a constructor, any constructor on this class's superclass.
    static String superCtorCall(ClassInfo cl, ClassInfo[] thrownExceptions) {
        ClassInfo base = cl.realSuperclass();
        if (base == null) {
            return "";
        }
        HashSet<String> exceptionNames = new HashSet<String>();
        if (thrownExceptions != null ){
            for (ClassInfo thrown : thrownExceptions){
              exceptionNames.add(thrown.name());
            }
        }
        MethodInfo[] ctors = base.constructors();
        MethodInfo ctor = null;
        //bad exception indicates that the exceptions thrown by the super constructor
        //are incompatible with the constructor we're using for the sub class.
        Boolean badException = false;
        for (MethodInfo m: ctors) {
            if (canCallMethod(cl, m)) {
                if (m.thrownExceptions() != null){
                    for (ClassInfo thrown : m.thrownExceptions()){
                        if (!exceptionNames.contains(thrown.name())){
                            badException = true;
                        }
                    }
                }
                if (badException){
                  badException = false;
                  continue;
                }
                // if it has no args, we're done
                if (m.parameters().length == 0) {
                    return "";
                }
                ctor = m;
            }
        }
        if (ctor != null) {
            String result = "";
            result+= "super(";
            ParameterInfo[] params = ctor.parameters();
            int N = params.length;
            for (int i=0; i<N; i++) {
                TypeInfo t = params[i].type();
                if (t.isPrimitive() && t.dimension().equals("")) {
                    String n = t.simpleTypeName();
                    if (("byte".equals(n)
                            || "short".equals(n)
                            || "int".equals(n)
                            || "long".equals(n)
                            || "float".equals(n)
                            || "double".equals(n)) && t.dimension().equals("")) {
                        result += "0";
                    }
                    else if ("char".equals(n)) {
                        result += "'\\0'";
                    }
                    else if ("boolean".equals(n)) {
                        result += "false";
                    }
                    else {
                        result += "<<unknown-" + n + ">>";
                    }
                } else {
                    //put null in each super class method.  Cast null to the correct type
                    //to avoid collisions with other constructors.  If the type is generic
                    //don't cast it
                    result += (!t.isTypeVariable() ? "(" + t.qualifiedTypeName() + t.dimension() +
                              ")" : "") + "null";
                }
                if (i != N-1) {
                    result += ",";
                }
            }
            result += "); ";
            return result;
        } else {
            return "";
        }
    }

    static void writeAnnotations(PrintStream stream, AnnotationInstanceInfo[] annotations) {
        for (AnnotationInstanceInfo ann: annotations) {
            if (!ann.type().isHidden()) {
                stream.println(ann.toString());
            }
        }
    }

    static void writeAnnotationElement(PrintStream stream, MethodInfo ann) {
        stream.print(ann.returnType().fullName());
        stream.print(" ");
        stream.print(ann.name());
        stream.print("()");
        AnnotationValueInfo def = ann.defaultAnnotationElementValue();
        if (def != null) {
            stream.print(" default ");
            stream.print(def.valueString());
        }
        stream.println(";");
    }

    static void writeXML(PrintStream xmlWriter, HashMap<PackageInfo, List<ClassInfo>> allClasses,
                         HashSet notStrippable) {
        // extract the set of packages, sort them by name, and write them out in that order
        Set<PackageInfo> allClassKeys = allClasses.keySet();
        PackageInfo[] allPackages = allClassKeys.toArray(new PackageInfo[allClassKeys.size()]);
        Arrays.sort(allPackages, PackageInfo.comparator);

        xmlWriter.println("<api>");
        for (PackageInfo pack : allPackages) {
            writePackageXML(xmlWriter, pack, allClasses.get(pack), notStrippable);
        }
        xmlWriter.println("</api>");
    }

    static void writePackageXML(PrintStream xmlWriter, PackageInfo pack, List<ClassInfo> classList,
                                HashSet notStrippable) {
        ClassInfo[] classes = classList.toArray(new ClassInfo[classList.size()]);
        Arrays.sort(classes, ClassInfo.comparator);
        // Work around the bogus "Array" class we invent for
        // Arrays.copyOf's Class<? extends T[]> newType parameter. (http://b/2715505)
        if (pack.name().equals("")) {
            return;
        }
        xmlWriter.println("<package name=\"" + pack.name() + "\"\n"
                //+ " source=\"" + pack.position() + "\"\n"
                + ">");
        for (ClassInfo cl : classes) {
            writeClassXML(xmlWriter, cl, notStrippable);
        }
        xmlWriter.println("</package>");


    }

    static void writeClassXML(PrintStream xmlWriter, ClassInfo cl, HashSet notStrippable) {
        String scope = DroidDoc.scope(cl);
        String deprecatedString = "";
        String declString = (cl.isInterface()) ? "interface" : "class";
        if (cl.isDeprecated()) {
            deprecatedString = "deprecated";
        } else {
            deprecatedString = "not deprecated";
        }
        xmlWriter.println("<" + declString + " name=\"" + cl.name() + "\"");
        if (!cl.isInterface() && !cl.qualifiedName().equals("java.lang.Object")) {
            xmlWriter.println(" extends=\"" + ((cl.realSuperclass() == null)
                            ? "java.lang.Object"
                            : cl.realSuperclass().qualifiedName()) + "\"");
        }
        xmlWriter.println(" abstract=\"" + cl.isAbstract() + "\"\n"
                + " static=\"" + cl.isStatic() + "\"\n"
                + " final=\"" + cl.isFinal() + "\"\n"
                + " deprecated=\"" + deprecatedString + "\"\n"
                + " visibility=\"" + scope + "\"\n"
                //+ " source=\"" + cl.position() + "\"\n"
                + ">");

        ClassInfo[] interfaces = cl.realInterfaces();
        Arrays.sort(interfaces, ClassInfo.comparator);
        for (ClassInfo iface : interfaces) {
            if (notStrippable.contains(iface)) {
                xmlWriter.println("<implements name=\"" + iface.qualifiedName() + "\">");
                xmlWriter.println("</implements>");
            }
        }

        MethodInfo[] constructors = cl.constructors();
        Arrays.sort(constructors, MethodInfo.comparator);
        for (MethodInfo mi : constructors) {
            writeConstructorXML(xmlWriter, mi);
        }

        MethodInfo[] methods = cl.allSelfMethods();
        Arrays.sort(methods, MethodInfo.comparator);
        for (MethodInfo mi : methods) {
            if (!methodIsOverride(mi)) {
                writeMethodXML(xmlWriter, mi);
            }
        }

        FieldInfo[] fields = cl.allSelfFields();
        Arrays.sort(fields, FieldInfo.comparator);
        for (FieldInfo fi : fields) {
            writeFieldXML(xmlWriter, fi);
        }
        xmlWriter.println("</" + declString + ">");

    }

    static void writeMethodXML(PrintStream xmlWriter, MethodInfo mi) {
        String scope = DroidDoc.scope(mi);

        String deprecatedString = "";
        if (mi.isDeprecated()) {
            deprecatedString = "deprecated";
        } else {
            deprecatedString = "not deprecated";
        }
        xmlWriter.println("<method name=\"" + mi.name() + "\"\n"
                + ((mi.returnType() != null)
                        ? " return=\"" + makeXMLcompliant(fullParameterTypeName(mi, mi.returnType(), false)) + "\"\n"
                        : "")
                + " abstract=\"" + mi.isAbstract() + "\"\n"
                + " native=\"" + mi.isNative() + "\"\n"
                + " synchronized=\"" + mi.isSynchronized() + "\"\n"
                + " static=\"" + mi.isStatic() + "\"\n"
                + " final=\"" + mi.isFinal() + "\"\n"
                + " deprecated=\""+ deprecatedString + "\"\n"
                + " visibility=\"" + scope + "\"\n"
                //+ " source=\"" + mi.position() + "\"\n"
                + ">");

        // write parameters in declaration order
        int numParameters = mi.parameters().length;
        int count = 0;
        for (ParameterInfo pi : mi.parameters()) {
            count++;
            writeParameterXML(xmlWriter, mi, pi, count == numParameters);
        }

        // but write exceptions in canonicalized order
        ClassInfo[] exceptions = mi.thrownExceptions();
        Arrays.sort(exceptions, ClassInfo.comparator);
        for (ClassInfo pi : exceptions) {
          xmlWriter.println("<exception name=\"" + pi.name() +"\" type=\"" + pi.qualifiedName()
                            + "\">");
          xmlWriter.println("</exception>");
        }
        xmlWriter.println("</method>");
    }

    static void writeConstructorXML(PrintStream xmlWriter, MethodInfo mi) {
        String scope = DroidDoc.scope(mi);
        String deprecatedString = "";
        if (mi.isDeprecated()) {
            deprecatedString = "deprecated";
        } else {
            deprecatedString = "not deprecated";
        }
        xmlWriter.println("<constructor name=\"" + mi.name() + "\"\n"
                + " type=\"" + mi.containingClass().qualifiedName() + "\"\n"
                + " static=\"" + mi.isStatic() + "\"\n"
                + " final=\"" + mi.isFinal() + "\"\n"
                + " deprecated=\"" + deprecatedString + "\"\n"
                + " visibility=\"" + scope +"\"\n"
                //+ " source=\"" + mi.position() + "\"\n"
                + ">");

        int numParameters = mi.parameters().length;
        int count = 0;
        for (ParameterInfo pi : mi.parameters()) {
            count++;
            writeParameterXML(xmlWriter, mi, pi, count == numParameters);
        }

        ClassInfo[] exceptions = mi.thrownExceptions();
        Arrays.sort(exceptions, ClassInfo.comparator);
        for (ClassInfo pi : exceptions) {
            xmlWriter.println("<exception name=\"" + pi.name() +"\" type=\"" + pi.qualifiedName()
                              + "\">");
            xmlWriter.println("</exception>");
        }
        xmlWriter.println("</constructor>");
  }

    static void writeParameterXML(PrintStream xmlWriter, MethodInfo method,
            ParameterInfo pi, boolean isLast) {
        xmlWriter.println("<parameter name=\"" + pi.name() + "\" type=\"" +
                makeXMLcompliant(fullParameterTypeName(method, pi.type(), isLast)) + "\">");
        xmlWriter.println("</parameter>");
    }

    static void writeFieldXML(PrintStream xmlWriter, FieldInfo fi) {
        String scope = DroidDoc.scope(fi);
        String deprecatedString = "";
        if (fi.isDeprecated()) {
            deprecatedString = "deprecated";
        } else {
            deprecatedString = "not deprecated";
        }
        //need to make sure value is valid XML
        String value  = makeXMLcompliant(fi.constantLiteralValue());

        String fullTypeName = makeXMLcompliant(fi.type().qualifiedTypeName())
                + fi.type().dimension();

        xmlWriter.println("<field name=\"" + fi.name() +"\"\n"
                          + " type=\"" + fullTypeName + "\"\n"
                          + " transient=\"" + fi.isTransient() + "\"\n"
                          + " volatile=\"" + fi.isVolatile() + "\"\n"
                          + (fieldIsInitialized(fi) ? " value=\"" + value + "\"\n" : "")
                          + " static=\"" + fi.isStatic() + "\"\n"
                          + " final=\"" + fi.isFinal() + "\"\n"
                          + " deprecated=\"" + deprecatedString + "\"\n"
                          + " visibility=\"" + scope + "\"\n"
                          //+ " source=\"" + fi.position() + "\"\n"
                          + ">");
        xmlWriter.println("</field>");
    }

    static String makeXMLcompliant(String s) {
        String returnString = "";
        returnString = s.replaceAll("&", "&amp;");
        returnString = returnString.replaceAll("<", "&lt;");
        returnString = returnString.replaceAll(">", "&gt;");
        returnString = returnString.replaceAll("\"", "&quot;");
        returnString = returnString.replaceAll("'", "&pos;");
        return returnString;
    }

    static String fullParameterTypeName(MethodInfo method, TypeInfo type, boolean isLast) {
        String fullTypeName = type.fullName(method.typeVariables());
        if (isLast && method.isVarArgs()) {
            // TODO: note that this does not attempt to handle hypothetical
            // vararg methods whose last parameter is a list of arrays, e.g.
            // "Object[]...".
            fullTypeName = type.fullNameNoDimension(method.typeVariables()) + "...";
        }
        return fullTypeName;
    }
}
