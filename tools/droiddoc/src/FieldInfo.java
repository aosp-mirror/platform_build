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

import java.util.Comparator;

public class FieldInfo extends MemberInfo
{
    public static final Comparator<FieldInfo> comparator = new Comparator<FieldInfo>() {
        public int compare(FieldInfo a, FieldInfo b) {
            return a.name().compareTo(b.name());
        }
    };
    
    public FieldInfo(String name, ClassInfo containingClass, ClassInfo realContainingClass,
                        boolean isPublic, boolean isProtected,
                        boolean isPackagePrivate, boolean isPrivate,
                        boolean isFinal, boolean isStatic, boolean isTransient, boolean isVolatile,
                        boolean isSynthetic, TypeInfo type, String rawCommentText,
                        Object constantValue,
                        SourcePositionInfo position,
                        AnnotationInstanceInfo[] annotations)
    {
        super(rawCommentText, name, null, containingClass, realContainingClass,
                isPublic, isProtected, isPackagePrivate, isPrivate,
                isFinal, isStatic, isSynthetic, chooseKind(isFinal, isStatic), position,
                annotations);
        mIsTransient = isTransient;
        mIsVolatile = isVolatile;
        mType = type;
        mConstantValue = constantValue;
    }

    public FieldInfo cloneForClass(ClassInfo newContainingClass) {
        return new FieldInfo(name(), newContainingClass, realContainingClass(),
                isPublic(), isProtected(), isPackagePrivate(),
                isPrivate(), isFinal(), isStatic(), isTransient(), isVolatile(),
                isSynthetic(), mType, getRawCommentText(), mConstantValue, position(),
                annotations());
    }

    static String chooseKind(boolean isFinal, boolean isStatic)
    {
        if (isStatic && isFinal) {
            return "constant";
        } else {
            return "field";
        }
    }

    public TypeInfo type()
    {
        return mType;
    }

    public boolean isConstant()
    {
        return isStatic() && isFinal();
    }

    public TagInfo[] firstSentenceTags()
    {
        return comment().briefTags();
    }

    public TagInfo[] inlineTags()
    {
        return comment().tags();
    }

    public Object constantValue()
    {
        return mConstantValue;
    }

    public String constantLiteralValue()
    {
        return constantLiteralValue(mConstantValue);
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
                        "Field " + mContainingClass.qualifiedName() + "." + name()
                        + ": @Deprecated annotation and @deprecated comment do not match");
            }

            mIsDeprecated = commentDeprecated | annotationDeprecated;
            mDeprecatedKnown = true;
        }
        return mIsDeprecated;
    }

    public static String constantLiteralValue(Object val)
    {
        String str = null;
        if (val != null) {
            if (val instanceof Boolean
                    || val instanceof Byte
                    || val instanceof Short
                    || val instanceof Integer) 
            {
                str = val.toString();
            }
            //catch all special values
            else if (val instanceof Double){
                Double dbl = (Double) val;
                    if (dbl.toString().equals("Infinity")){
                        str = "(1.0 / 0.0)";
                    } else if (dbl.toString().equals("-Infinity")) {
                        str = "(-1.0 / 0.0)";
                    } else if (dbl.isNaN()) {
                        str = "(0.0 / 0.0)";
                    } else {
                        str = dbl.toString();
                    }
            }
            else if (val instanceof Long) {
                str = val.toString() + "L";
            }
            else if (val instanceof Float) {
                Float fl = (Float) val;
                if (fl.toString().equals("Infinity")) {
                    str = "(1.0f / 0.0f)";
                } else if (fl.toString().equals("-Infinity")) {
                    str = "(-1.0f / 0.0f)";
                } else if (fl.isNaN()) {
                    str = "(0.0f / 0.0f)";
                } else {
                    str = val.toString() + "f";
                }
            }
            else if (val instanceof Character) {
                str = String.format("\'\\u%04x\'", val);
            }
            else if (val instanceof String) {
                str = "\"" + javaEscapeString((String)val) + "\"";
            }
            else {
                str = "<<<<" +val.toString() + ">>>>";
            }
        }
        if (str == null) {
            str = "null";
        }
        return str;
    }

    public static String javaEscapeString(String str) {
        String result = "";
        final int N = str.length();
        for (int i=0; i<N; i++) {
            char c = str.charAt(i);
            if (c == '\\') {
                result += "\\\\";
            }
            else if (c == '\t') {
                result += "\\t";
            }
            else if (c == '\b') {
                result += "\\b";
            }
            else if (c == '\r') {
                result += "\\r";
            }
            else if (c == '\n') {
                result += "\\n";
            }
            else if (c == '\f') {
                result += "\\f";
            }
            else if (c == '\'') {
                result += "\\'";
            }
            else if (c == '\"') {
                result += "\\\"";
            }
            else if (c >= ' ' && c <= '~') {
                result += c;
            }
            else {
                result += String.format("\\u%04x", new Integer((int)c));
            }
        }
        return result;
    }


    public void makeHDF(HDF data, String base)
    {
        data.setValue(base + ".kind", kind());
        type().makeHDF(data, base + ".type");
        data.setValue(base + ".name", name());
        data.setValue(base + ".href", htmlPage());
        data.setValue(base + ".anchor", anchor());
        TagInfo.makeHDF(data, base + ".shortDescr", firstSentenceTags());
        TagInfo.makeHDF(data, base + ".descr", inlineTags());
        TagInfo.makeHDF(data, base + ".deprecated", comment().deprecatedTags());
        TagInfo.makeHDF(data, base + ".seeAlso", comment().seeTags());
        data.setValue(base + ".final", isFinal() ? "final" : "");
        data.setValue(base + ".static", isStatic() ? "static" : "");
        if (isPublic()) {
            data.setValue(base + ".scope", "public");
        }
        else if (isProtected()) {
            data.setValue(base + ".scope", "protected");
        }
        else if (isPackagePrivate()) {
            data.setValue(base + ".scope", "");
        }
        else if (isPrivate()) {
            data.setValue(base + ".scope", "private");
        }
        Object val = mConstantValue;
        if (val != null) {
            String dec = null;
            String hex = null;
            String str = null;

            if (val instanceof Boolean) {
                str = ((Boolean)val).toString();
            }
            else if (val instanceof Byte) {
                dec = String.format("%d", val);
                hex = String.format("0x%02x", val);
            }
            else if (val instanceof Character) {
                dec = String.format("\'%c\'", val);
                hex = String.format("0x%04x", val);
            }
            else if (val instanceof Double) {
                str = ((Double)val).toString();
            }
            else if (val instanceof Float) {
                str = ((Float)val).toString();
            }
            else if (val instanceof Integer) {
                dec = String.format("%d", val);
                hex = String.format("0x%08x", val);
            }
            else if (val instanceof Long) {
                dec = String.format("%d", val);
                hex = String.format("0x%016x", val);
            }
            else if (val instanceof Short) {
                dec = String.format("%d", val);
                hex = String.format("0x%04x", val);
            }
            else if (val instanceof String) {
                str = "\"" + ((String)val) + "\"";
            }
            else {
                str = "";
            }

            if (dec != null && hex != null) {
                data.setValue(base + ".constantValue.dec", DroidDoc.escape(dec));
                data.setValue(base + ".constantValue.hex", DroidDoc.escape(hex));
            }
            else {
                data.setValue(base + ".constantValue.str", DroidDoc.escape(str));
                data.setValue(base + ".constantValue.isString", "1");
            }
        }
    }

    public boolean isExecutable()
    {
        return false;
    }

    public boolean isTransient()
    {
        return mIsTransient;
    }

    public boolean isVolatile()
    {
        return mIsVolatile;
    }

    boolean mIsTransient;
    boolean mIsVolatile;
    boolean mDeprecatedKnown;
    boolean mIsDeprecated;
    TypeInfo mType;
    Object mConstantValue;
}

