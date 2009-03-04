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

import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.ArrayList;

/**
 * Class that represents what you see in an link or see tag.  This is
 * factored out of SeeTagInfo so it can be used elsewhere (like AttrTagInfo).
 */
public class LinkReference {

    /** The original text. */
    public String text;
    
    /** The kind of this tag, if we have a new suggestion after parsing. */
    public String kind;

    /** The user visible text. */
    public String label;

    /** The link. */
    public String href;

    /** The {@link PackageInfo} if any. */
    public PackageInfo packageInfo;

    /** The {@link ClassInfo} if any. */
    public ClassInfo classInfo;

    /** The {@link MemberInfo} if any. */
    public MemberInfo memberInfo;

    /** The name of the referenced member PackageInfo} if any. */
    public String referencedMemberName;

    /** Set to true if everything is a-ok */
    public boolean good;

    /**
     * regex pattern to use when matching explicit "<a href" reference text
     */
    private static final Pattern HREF_PATTERN
            = Pattern.compile("^<a href=\"([^\"]*)\">([^<]*)</a>[ \n\r\t]*$",
                              Pattern.CASE_INSENSITIVE);

    /**
     * Parse and resolve a link string.
     *
     * @param text the original text
     * @param base the class or whatever that this link is on
     * @param pos the original position in the source document
     * @return a new link reference.  It always returns something.  If there was an
     *         error, it logs it and fills in href and label with error text.
     */
    public static LinkReference parse(String text, ContainerInfo base, SourcePositionInfo pos,
                                        boolean printOnErrors) {
        LinkReference result = new LinkReference();
        result.text = text;

        int index;
        int len = text.length();
        int pairs = 0;
        int pound = -1;
        // split the string
        done: {
            for (index=0; index<len; index++) {
                char c = text.charAt(index);
                switch (c)
                {
                    case '(':
                        pairs++;
                        break;
                    case '[':
                        pairs++;
                        break;
                    case ')':
                        pairs--;
                        break;
                    case ']':
                        pairs--;
                        break;
                    case ' ':
                    case '\t':
                    case '\r':
                    case '\n':
                        if (pairs == 0) {
                            break done;
                        }
                        break;
                    case '#':
                        if (pound < 0) {
                            pound = index;
                        }
                        break;
                }
            }
        }
        if (index == len && pairs != 0) {
            Errors.error(Errors.UNRESOLVED_LINK, pos,
                        "unable to parse link/see tag: " + text.trim());
            return result;
        }

        int linkend = index;

        for (; index<len; index++) {
            char c = text.charAt(index);
            if (!(c == ' ' || c == '\t' || c == '\r' || c == '\n')) {
                break;
            }
        }

        result.label = text.substring(index);

        String ref;
        String mem;
        if (pound == 0) {
            ref = null;
            mem = text.substring(1, linkend);
        }
        else if (pound > 0) {
            ref = text.substring(0, pound);
            mem = text.substring(pound+1, linkend);
        }
        else {
            ref = text.substring(0, linkend);
            mem = null;
        }

        // parse parameters, if any
        String[] params = null;
        String[] paramDimensions = null;
        if (mem != null) {
            index = mem.indexOf('(');
            if (index > 0) {
                ArrayList<String> paramList = new ArrayList<String>();
                ArrayList<String> paramDimensionList = new ArrayList<String>();
                len = mem.length();
                int start = index+1;
                final int START = 0;
                final int TYPE = 1;
                final int NAME = 2;
                int dimension = 0;
                int arraypair = 0;
                int state = START;
                int typestart = 0;
                int typeend = -1;
                for (int i=start; i<len; i++) {
                    char c = mem.charAt(i);
                    switch (state)
                    {
                        case START:
                            if (c!=' ' && c!='\t' && c!='\r' && c!='\n') {
                                state = TYPE;
                                typestart = i;
                            }
                            break;
                        case TYPE:
                            if (c == '[') {
                                if (typeend < 0) {
                                    typeend = i;
                                }
                                dimension++;
                                arraypair++;
                            }
                            else if (c == ']') {
                                arraypair--;
                            }
                            else if (c==' ' || c=='\t' || c=='\r' || c=='\n') {
                                if (typeend < 0) {
                                    typeend = i;
                                }
                            }
                            else {
                                if (typeend >= 0 || c == ')' || c == ',') {
                                    if (typeend < 0) {
                                        typeend = i;
                                    }
                                    String s = mem.substring(typestart, typeend);
                                    paramList.add(s);
                                    s = "";
                                    for (int j=0; j<dimension; j++) {
                                        s += "[]";
                                    }
                                    paramDimensionList.add(s);
                                    state = START;
                                    typeend = -1;
                                    dimension = 0;
                                    if (c == ',' || c == ')') {
                                        state = START;
                                    } else {
                                        state = NAME;
                                    }
                                }
                            }
                            break;
                        case NAME:
                            if (c == ',' || c == ')') {
                                state = START;
                            }
                            break;
                    }

                }
                params = paramList.toArray(new String[paramList.size()]);
                paramDimensions = paramDimensionList.toArray(new String[paramList.size()]);
                mem = mem.substring(0, index);
            }
        }

        ClassInfo cl = null;
        if (base instanceof ClassInfo) {
            cl = (ClassInfo)base;
        }

        if (ref == null) {
            // no class or package was provided, assume it's this class
            if (cl != null) {
                result.classInfo = cl;
            }
        } else {
            // they provided something, maybe it's a class or a package
            if (cl != null) {
                result.classInfo = cl.extendedFindClass(ref);
                if (result.classInfo == null) {
                    result.classInfo = cl.findClass(ref);
                }
                if (result.classInfo == null) {
                    result.classInfo = cl.findInnerClass(ref);
                }
            }
            if (result.classInfo == null) {
                result.classInfo = Converter.obtainClass(ref);
            }
            if (result.classInfo == null) {
                result.packageInfo = Converter.obtainPackage(ref);
            }
        }

        if (result.classInfo != null && mem != null) {
            // it's either a field or a method, prefer a field
            if (params == null) {
                FieldInfo field = result.classInfo.findField(mem);
                // findField looks in containing classes, so it might actually
                // be somewhere else; link to where it really is, not what they
                // typed.
                if (field != null) {
                    result.classInfo = field.containingClass();
                    result.memberInfo = field;
                }
            }
            if (result.memberInfo == null) {
                MethodInfo method = result.classInfo.findMethod(mem, params, paramDimensions);
                if (method != null) {
                    result.classInfo = method.containingClass();
                    result.memberInfo = method;
                }
            }
        }

        result.referencedMemberName = mem;
        if (params != null) {
            result.referencedMemberName = result.referencedMemberName + '(';
            len = params.length;
            if (len > 0) {
                len--;
                for (int i=0; i<len; i++) {
                    result.referencedMemberName = result.referencedMemberName + params[i]
                            + paramDimensions[i] + ", ";
                }
                result.referencedMemberName = result.referencedMemberName + params[len]
                        + paramDimensions[len];
            }
            result.referencedMemberName = result.referencedMemberName + ")";
        }

        // debugging spew
        if (false) {
            result.label = result.label + "/" + ref + "/" + mem + '/';
            if (params != null) {
                for (int i=0; i<params.length; i++) {
                    result.label += params[i] + "|";
                }
            }

            FieldInfo f = (result.memberInfo instanceof FieldInfo)
                        ? (FieldInfo)result.memberInfo
                        : null;
            MethodInfo m = (result.memberInfo instanceof MethodInfo)
                        ? (MethodInfo)result.memberInfo
                        : null;
            result.label = result.label
                        + "/package=" + (result.packageInfo!=null?result.packageInfo.name():"")
                        + "/class=" + (result.classInfo!=null?result.classInfo.qualifiedName():"")
                        + "/field=" + (f!=null?f.name():"")
                        + "/method=" + (m!=null?m.name():"");
            
        }

        MethodInfo method = null;
        boolean skipHref = false;

        if (result.memberInfo != null && result.memberInfo.isExecutable()) {
           method = (MethodInfo)result.memberInfo;
        }

        if (text.startsWith("\"")) {
            // literal quoted reference (e.g., a book title)
            result.label = text.substring(1);
            skipHref = true;
            if (!result.label.endsWith("\"")) {
                Errors.error(Errors.UNRESOLVED_LINK, pos,
                        "unbalanced quoted link/see tag: " + text.trim());
                result.makeError();
                return result;
            }
            result.label = result.label.substring(0, result.label.length() - 1);
            result.kind = "@seeJustLabel";
        }
        else if (text.startsWith("<")) {
            // explicit "<a href" form
            Matcher matcher = HREF_PATTERN.matcher(text);
            if (! matcher.matches()) {
                Errors.error(Errors.UNRESOLVED_LINK, pos,
                        "invalid <a> link/see tag: " + text.trim());
                result.makeError();
                return result;
            }
            result.href = matcher.group(1);
            result.label = matcher.group(2);
            result.kind = "@seeHref";
        }
        else if (result.packageInfo != null) {
            result.href = result.packageInfo.htmlPage();
            if (result.label.length() == 0) {
                result.href = result.packageInfo.htmlPage();
                result.label = result.packageInfo.name();
            }
        }
        else if (result.classInfo != null && result.referencedMemberName == null) {
            // class reference
            if (result.label.length() == 0) {
                result.label = result.classInfo.name();
            }
            result.href = result.classInfo.htmlPage();
        }
        else if (result.memberInfo != null) {
            // member reference
            ClassInfo containing = result.memberInfo.containingClass();
            if (result.memberInfo.isExecutable()) {
                if (result.referencedMemberName.indexOf('(') < 0) {
                    result.referencedMemberName += method.flatSignature();
                }
            } 
            if (result.label.length() == 0) {
                result.label = result.referencedMemberName;
            }
            result.href = containing.htmlPage() + '#' + result.memberInfo.anchor();
        }

        if (result.href == null && !skipHref) {
            if (printOnErrors && (base == null || base.checkLevel())) {
                Errors.error(Errors.UNRESOLVED_LINK, pos,
                        "Unresolved link/see tag \"" + text.trim()
                        + "\" in " + ((base != null) ? base.qualifiedName() : "[null]"));
            }
            result.makeError();
        }
        else if (result.memberInfo != null && !result.memberInfo.checkLevel()) {
            if (printOnErrors && (base == null || base.checkLevel())) {
                Errors.error(Errors.HIDDEN_LINK, pos,
                        "Link to hidden member: " + text.trim());
                result.href = null;
            }
            result.kind = "@seeJustLabel";
        }
        else if (result.classInfo != null && !result.classInfo.checkLevel()) {
            if (printOnErrors && (base == null || base.checkLevel())) {
                Errors.error(Errors.HIDDEN_LINK, pos,
                        "Link to hidden class: " + text.trim() + " label=" + result.label);
                result.href = null;
            }
            result.kind = "@seeJustLabel";
        }
        else if (result.packageInfo != null && !result.packageInfo.checkLevel()) {
            if (printOnErrors && (base == null || base.checkLevel())) {
                Errors.error(Errors.HIDDEN_LINK, pos,
                        "Link to hidden package: " + text.trim());
                result.href = null;
            }
            result.kind = "@seeJustLabel";
        }

        result.good = true;

        return result;
    }

    public boolean checkLevel() {
        if (memberInfo != null) {
            return memberInfo.checkLevel();
        }
        if (classInfo != null) {
            return classInfo.checkLevel();
        }
        if (packageInfo != null) {
            return packageInfo.checkLevel();
        }
        return false;
    }

    /** turn this LinkReference into one with an error message */
    private void makeError() {
        //this.href = "ERROR(" + this.text.trim() + ")";
        this.href = null;
        if (this.label == null) {
            this.label = "";
        }
        this.label = "ERROR(" + this.label + "/" + text.trim() + ")";
    }

    /** private. **/
    private LinkReference() {
    }
}
