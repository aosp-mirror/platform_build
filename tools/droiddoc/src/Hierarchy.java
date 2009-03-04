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
import java.util.TreeSet;
import java.util.Set;
import org.clearsilver.HDF;

public class Hierarchy
{
    public static void makeHierarchy(HDF hdf, ClassInfo[] classes)
    {
        HashMap<String,TreeSet<String>> nodes
                                    = new HashMap<String,TreeSet<String>>();

        for (ClassInfo cl: classes) {
            String name = cl.qualifiedName();

            TreeSet<String> me = nodes.get(name);
            if (me == null) {
                me = new TreeSet<String>();
                nodes.put(name, me);
            }

            ClassInfo superclass = cl.superclass();
            String sname = superclass != null
                                    ? superclass.qualifiedName() : null;
            if (sname != null) {
                TreeSet<String> s = nodes.get(sname);
                if (s == null) {
                    s = new TreeSet<String>();
                    nodes.put(sname, s);
                }
                s.add(name);
            }
        }

        /*
        Set<String> keys = nodes.keySet();
        for (String n: keys) {
            System.out.println("class: " + n);

            TreeSet<String> values = nodes.get(n);
            for (String v: values) {
                System.out.println("       - " + v);
            }
        }
        */

        int depth = depth(nodes, "java.lang.Object");

        hdf.setValue("classes.0", "");
        hdf.setValue("colspan", "" + depth);

        recurse(nodes, "java.lang.Object", hdf.getObj("classes.0"),depth,depth);

        if (false) {
            Set<String> keys = nodes.keySet();
            if (keys.size() > 0) {
                System.err.println("The following classes are hidden but"
                        + " are superclasses of not-hidden classes");
                for (String n: keys) {
                    System.err.println("  " + n);
                }
            }
        }
    }

    private static int depth(HashMap<String,TreeSet<String>> nodes,
                                String name)
    {
        int d = 0;
        TreeSet<String> derived = nodes.get(name);
        if (derived != null && derived.size() > 0) {
            for (String s: derived) {
                int n = depth(nodes, s);
                if (n > d) {
                    d = n;
                }
            }
        }
        return d + 1;
    }

    private static boolean exists(ClassInfo cl)
    {
        return cl != null && !cl.isHidden() && cl.isIncluded();
    }

    private static void recurse(HashMap<String,TreeSet<String>> nodes,
                                String name, HDF hdf, 
                                int totalDepth, int remainingDepth)
    {
        int i;

        hdf.setValue("indent", "" + (totalDepth-remainingDepth-1));
        hdf.setValue("colspan", "" + remainingDepth);

        ClassInfo cl = Converter.obtainClass(name);

        hdf.setValue("class.label", cl.name());
        hdf.setValue("class.qualified", cl.qualifiedName());
        if (cl.checkLevel()) {
            hdf.setValue("class.link", cl.htmlPage());
        }

        if (exists(cl)) {
            hdf.setValue("exists", "1");
        }

        i = 0;
        for (ClassInfo iface: cl.interfaces()) {
            hdf.setValue("interfaces." + i + ".class.label", iface.name());
            hdf.setValue("interfaces." + i + ".class.qualified", iface.qualifiedName());
            if (iface.checkLevel()) {
                hdf.setValue("interfaces." + i + ".class.link", iface.htmlPage());
            }
            if (exists(cl)) {
                hdf.setValue("interfaces." + i + ".exists", "1");
            }
            i++;
        }

        TreeSet<String> derived = nodes.get(name);
        if (derived != null && derived.size() > 0) {
            hdf.setValue("derived", "");
            HDF children = hdf.getObj("derived");
            i = 0;
            remainingDepth--;
            for (String s: derived) {
                String index = "" + i;
                children.setValue(index, "");
                recurse(nodes, s, children.getObj(index), totalDepth,
                        remainingDepth);
                i++;
            }
        }

        nodes.remove(name);
    }
}

