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

import java.util.ArrayList;

public class NavTree {

    public static void writeNavTree(String dir) {
        ArrayList<Node> children = new ArrayList();
        for (PackageInfo pkg: DroidDoc.choosePackages()) {
            children.add(makePackageNode(pkg));
        }
        Node node = new Node("Reference", dir + "packages.html", children);

        StringBuilder buf = new StringBuilder();
        if (false) {
            // if you want a root node
            buf.append("[");
            node.render(buf);
            buf.append("]");
        } else {
            // if you don't want a root node
            node.renderChildren(buf);
        }

        HDF data = DroidDoc.makeHDF();
        data.setValue("reference_tree", buf.toString());
        ClearPage.write(data, "navtree_data.cs", "navtree_data.js");
    }

    private static Node makePackageNode(PackageInfo pkg) {
        ArrayList<Node> children = new ArrayList();

        children.add(new Node("Description", pkg.fullDescriptionHtmlPage(), null));

        addClassNodes(children, "Interfaces", pkg.interfaces());
        addClassNodes(children, "Classes", pkg.ordinaryClasses());
        addClassNodes(children, "Enums", pkg.enums());
        addClassNodes(children, "Exceptions", pkg.exceptions());
        addClassNodes(children, "Errors", pkg.errors());

        return new Node(pkg.name(), pkg.htmlPage(), children);
    }

    private static void addClassNodes(ArrayList<Node> parent, String label, ClassInfo[] classes) {
        ArrayList<Node> children = new ArrayList();

        for (ClassInfo cl: classes) {
            if (cl.checkLevel()) {
                children.add(new Node(cl.name(), cl.htmlPage(), null));
            }
        }

        if (children.size() > 0) {
            parent.add(new Node(label, null, children));
        }
    }

    private static class Node {
        private String mLabel;
        private String mLink;
        ArrayList<Node> mChildren;

        Node(String label, String link, ArrayList<Node> children) {
            mLabel = label;
            mLink = link;
            mChildren = children;
        }

        static void renderString(StringBuilder buf, String s) {
            if (s == null) {
                buf.append("null");
            } else {
                buf.append('"');
                final int N = s.length();
                for (int i=0; i<N; i++) {
                    char c = s.charAt(i);
                    if (c >= ' ' && c <= '~' && c != '"' && c != '\\') {
                        buf.append(c);
                    } else {
                        buf.append("\\u");
                        for (int j=0; i<4; i++) {
                            char x = (char)(c & 0x000f);
                            if (x > 10) {
                                x = (char)(x - 10 + 'a');
                            } else {
                                x = (char)(x + '0');
                            }
                            buf.append(x);
                            c >>= 4;
                        }
                    }
                }
                buf.append('"');
            }
        }

        void renderChildren(StringBuilder buf) {
            ArrayList<Node> list = mChildren;
            if (list == null || list.size() == 0) {
                // We output null for no children.  That way empty lists here can just
                // be a byproduct of how we generate the lists.
                buf.append("null");
            } else {
                buf.append("[ ");
                final int N = list.size();
                for (int i=0; i<N; i++) {
                    list.get(i).render(buf);
                    if (i != N-1) {
                        buf.append(", ");
                    }
                }
                buf.append(" ]\n");
            }
        }

        void render(StringBuilder buf) {
            buf.append("[ ");
            renderString(buf, mLabel);
            buf.append(", ");
            renderString(buf, mLink);
            buf.append(", ");
            renderChildren(buf);
            buf.append(" ]");
        }
    }
}
