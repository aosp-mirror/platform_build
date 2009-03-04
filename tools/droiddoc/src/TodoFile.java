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

public class TodoFile {

    public static final String MISSING = "No description text";

    public static boolean areTagsUseful(InheritedTags tags) {
        while (tags != null) {
            if (areTagsUseful(tags.tags())) {
                return true;
            }
            tags = tags.inherited();
        }
        return false;
    }

    public static boolean areTagsUseful(TagInfo[] tags) {
        for (TagInfo t: tags) {
            if ("Text".equals(t.name()) && t.text().trim().length() != 0) {
                return true;
            }
            if ("@inheritDoc".equals(t.name())) {
                return true;
            }
        }
        return false;
    }

    public static void setHDF(HDF data, String base, SourcePositionInfo pos, String name,
            String descr) {
        data.setValue(base + ".pos", pos.toString());
        data.setValue(base + ".name", name);
        data.setValue(base + ".descr", descr);
    }

    static class PackageStats {
        String name;
        public int total;
        public int errors;
    }

    public static String percent(int a, int b) {
        return ""+Math.round((((b-a)/(float)b))*100) + "%";
    }

    public static void writeTodoFile(String filename) {
        HDF data = DroidDoc.makeHDF();
        DroidDoc.setPageTitle(data, "Missing Documentation");
        TreeMap<String,PackageStats> packageStats = new TreeMap<String,PackageStats>();

        ClassInfo[] classes = Converter.rootClasses();
        Arrays.sort(classes);

        int classIndex = 0;
        
        for (ClassInfo cl: classes) {
            if (cl.isHidden()) {
                continue;
            }

            String classBase = "classes." + classIndex;

            String base = classBase + ".errors.";
            int errors = 0;
            int total = 1;

            if (!areTagsUseful(cl.inlineTags())) {
                setHDF(data, base + errors, cl.position(), "&lt;class comment&gt;", MISSING);
                errors++;
            }


            for (MethodInfo m: cl.constructors()) {
                boolean good = true;
                total++;
                if (m.checkLevel()) {
                    if (!areTagsUseful(m.inlineTags())) {
                        setHDF(data, base + errors, m.position(), m.name() + m.prettySignature(),
                                MISSING);
                        good = false;
                    }
                }
                if (!good) {
                    errors++;
                }
            }
            
            for (MethodInfo m: cl.selfMethods()) {
                boolean good = true;
                total++;
                if (m.checkLevel()) {
                    if (!areTagsUseful(m.inlineTags())) {
                        setHDF(data, base + errors, m.position(), m.name() + m.prettySignature(),
                                MISSING);
                        good = false;
                    }
                }
                if (!good) {
                    errors++;
                }
            }
            

            for (FieldInfo f: cl.enumConstants()) {
                boolean good = true;
                total++;
                if (f.checkLevel()) {
                    if (!areTagsUseful(f.inlineTags())) {
                        setHDF(data, base + errors, f.position(), f.name(), MISSING);
                        good = false;
                    }
                }
                if (!good) {
                    errors++;
                }
            }
            
            for (FieldInfo f: cl.selfFields()) {
                boolean good = true;
                total++;
                if (f.checkLevel()) {
                    if (!areTagsUseful(f.inlineTags())) {
                        setHDF(data, base + errors, f.position(), f.name(), MISSING);
                        good = false;
                    }
                }
                if (!good) {
                    errors++;
                }
            }

            if (errors > 0) {
                data.setValue(classBase + ".qualified", cl.qualifiedName());
                data.setValue(classBase + ".errorCount", ""+errors);
                data.setValue(classBase + ".totalCount", ""+total);
                data.setValue(classBase + ".percentGood", percent(errors, total));
            }

            PackageInfo pkg = cl.containingPackage();
            String pkgName = pkg != null ? pkg.name() : "";
            PackageStats ps = packageStats.get(pkgName);
            if (ps == null) {
                ps = new PackageStats();
                ps.name = pkgName;
                packageStats.put(pkgName, ps);
            }
            ps.total += total;
            ps.errors += errors;

            classIndex++;
        }

        int allTotal = 0;
        int allErrors = 0;

        int i = 0;
        for (PackageStats ps: packageStats.values()) {
            data.setValue("packages." + i + ".name", ""+ps.name);
            data.setValue("packages." + i + ".errorCount", ""+ps.errors);
            data.setValue("packages." + i + ".totalCount", ""+ps.total);
            data.setValue("packages." + i + ".percentGood", percent(ps.errors, ps.total));

            allTotal += ps.total;
            allErrors += ps.errors;

            i++;
        }

        data.setValue("all.errorCount", ""+allErrors);
        data.setValue("all.totalCount", ""+allTotal);
        data.setValue("all.percentGood", percent(allErrors, allTotal));

        ClearPage.write(data, "todo.cs", filename, true);
    }
}

