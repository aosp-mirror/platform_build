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

import org.xml.sax.*;
import org.xml.sax.helpers.*;
import java.io.*;
import java.util.ArrayList;
import java.util.Stack;

public class ApiCheck {
        // parse out and consume the -whatever command line flags
        private static ArrayList<String[]> parseFlags(ArrayList<String> allArgs) {
            ArrayList<String[]> ret = new ArrayList<String[]>();

            int i;
            for (i = 0; i < allArgs.size(); i++) {
                // flags with one value attached
                String flag = allArgs.get(i);
                if (flag.equals("-error")
                        || flag.equals("-warning")
                        || flag.equals("-hide")) {
                    String[] arg = new String[2];
                    arg[0] = flag;
                    arg[1] = allArgs.get(++i);
                    ret.add(arg);
                } else {
                    // we've consumed all of the -whatever args, so we're done
                    break;
                }
            }

            // i now points to the first non-flag arg; strip what came before
            for (; i > 0; i--) {
                allArgs.remove(0);
            }
            return ret;
        }

        public static void main(String[] originalArgs) {
            // translate to an ArrayList<String> for munging
            ArrayList<String> args = new ArrayList<String>(originalArgs.length);
            for (String a: originalArgs) {
                args.add(a);
            }

            ArrayList<String[]> flags = ApiCheck.parseFlags(args);
            for (String[] a: flags) {
                if (a[0].equals("-error") || a[0].equals("-warning")
                        || a[0].equals("-hide")) {
                    try {
                        int level = -1;
                        if (a[0].equals("-error")) {
                            level = Errors.ERROR;
                        }
                        else if (a[0].equals("-warning")) {
                            level = Errors.WARNING;
                        }
                        else if (a[0].equals("-hide")) {
                            level = Errors.HIDDEN;
                        }
                        Errors.setErrorLevel(Integer.parseInt(a[1]), level);
                    }
                    catch (NumberFormatException e) {
                        System.err.println("Bad argument: " + a[0] + " " + a[1]);
                        System.exit(2);
                    }
                }
            }

            ApiCheck acheck = new ApiCheck();

            ApiInfo oldApi = acheck.parseApi(args.get(0));
            ApiInfo newApi = acheck.parseApi(args.get(1));

            // only run the consistency check if we haven't had XML parse errors
            if (!Errors.hadError) {
                oldApi.isConsistent(newApi);
            }

            Errors.printErrors();
            System.exit(Errors.hadError ? 1 : 0);
        }

    public ApiInfo parseApi(String xmlFile) {
        FileReader fileReader = null;
        try {
            XMLReader xmlreader = XMLReaderFactory.createXMLReader();
            MakeHandler handler = new MakeHandler();
            xmlreader.setContentHandler(handler);
            xmlreader.setErrorHandler(handler);
            fileReader = new FileReader(xmlFile);
            xmlreader.parse(new InputSource(fileReader));
            ApiInfo apiInfo = handler.getApi();
            apiInfo.resolveSuperclasses();
            return apiInfo;
        } catch (SAXParseException e) {
            Errors.error(Errors.PARSE_ERROR,
                    new SourcePositionInfo(xmlFile, e.getLineNumber(), 0),
                    e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            Errors.error(Errors.PARSE_ERROR,
                    new SourcePositionInfo(xmlFile, 0, 0), e.getMessage());
        } finally {
            if (fileReader != null) {
                try {
                    fileReader.close();
                } catch (IOException ignored) {}
            }
        }
        return null;
    }

    private static class MakeHandler extends DefaultHandler {

            private ApiInfo mApi;
            private PackageInfo mCurrentPackage;
            private ClassInfo mCurrentClass;
            private AbstractMethodInfo mCurrentMethod;
            private Stack<ClassInfo> mClassScope = new Stack<ClassInfo>();


            public MakeHandler() {
                super();
                mApi = new ApiInfo();
            }

            @Override
            public void startElement(String uri, String localName, String qName,
                                     Attributes attributes) {
                if (qName.equals("package")) {
                    mCurrentPackage = new PackageInfo(attributes.getValue("name"),
                            SourcePositionInfo.fromXml(attributes.getValue("source")));
                } else if (qName.equals("class")
                        || qName.equals("interface")) {
                    // push the old outer scope for later recovery, then set
                    // up the new current class object
                    mClassScope.push(mCurrentClass);
                    mCurrentClass = new ClassInfo(attributes.getValue("name"),
                                                  mCurrentPackage,
                                                  attributes.getValue("extends") ,
                                                  qName.equals("interface"),
                                                  Boolean.valueOf(
                                                      attributes.getValue("abstract")),
                                                  Boolean.valueOf(
                                                      attributes.getValue("static")),
                                                  Boolean.valueOf(
                                                      attributes.getValue("final")),
                                                  attributes.getValue("deprecated"),
                                                  attributes.getValue("visibility"),
                                                  SourcePositionInfo.fromXml(attributes.getValue("source")),
                                                  mCurrentClass);
                } else if (qName.equals("method")) {
                    mCurrentMethod = new MethodInfo(attributes.getValue("name"),
                                                    attributes.getValue("return") ,
                                                    Boolean.valueOf(
                                                        attributes.getValue("abstract")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("native")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("synchronized")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("static")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("final")),
                                                    attributes.getValue("deprecated"),
                                                    attributes.getValue("visibility"),
                                                    SourcePositionInfo.fromXml(attributes.getValue("source")),
                                                    mCurrentClass);
                } else if (qName.equals("constructor")) {
                    mCurrentMethod = new ConstructorInfo(attributes.getValue("name"),
                                                         attributes.getValue("type") ,
                                                         Boolean.valueOf(
                                                             attributes.getValue("static")),
                                                         Boolean.valueOf(
                                                             attributes.getValue("final")),
                                                         attributes.getValue("deprecated"),
                                                         attributes.getValue("visibility"),
                                                         SourcePositionInfo.fromXml(attributes.getValue("source")),
                                                         mCurrentClass);
                } else if (qName.equals("field")) {
                    FieldInfo fInfo = new FieldInfo(attributes.getValue("name"),
                                                    attributes.getValue("type") ,
                                                    Boolean.valueOf(
                                                        attributes.getValue("transient")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("volatile")),
                                                    attributes.getValue("value"),
                                                    Boolean.valueOf(
                                                        attributes.getValue("static")),
                                                    Boolean.valueOf(
                                                        attributes.getValue("final")),
                                                    attributes.getValue("deprecated"),
                                                    attributes.getValue("visibility"),
                                                    SourcePositionInfo.fromXml(attributes.getValue("source")),
                                                    mCurrentClass);
                    mCurrentClass.addField(fInfo);
                } else if (qName.equals("parameter")) {
                    mCurrentMethod.addParameter(new ParameterInfo(attributes.getValue("type"),
                                                                  attributes.getValue("name")));
                } else if (qName.equals("exception")) {
                    mCurrentMethod.addException(attributes.getValue("type"));
                } else if (qName.equals("implements")) {
                    mCurrentClass.addInterface(attributes.getValue("name"));
                }
            }

            @Override
            public void endElement(String uri, String localName, String qName) {
                if (qName.equals("method")) {
                    mCurrentClass.addMethod((MethodInfo) mCurrentMethod);
                } else if (qName.equals("constructor")) {
                    mCurrentClass.addConstructor((ConstructorInfo) mCurrentMethod);
                } else if (qName.equals("class")
                        || qName.equals("interface")) {
                    mCurrentPackage.addClass(mCurrentClass);
                    mCurrentClass = mClassScope.pop();
                } else if (qName.equals("package")){
                    mApi.addPackage(mCurrentPackage);
                }
            }
            public ApiInfo getApi() {
                return mApi;
            }
        }
}
