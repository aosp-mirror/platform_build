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
import org.clearsilver.HDF;
import org.clearsilver.CS;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class ClearPage
{
    /*
    public ClearPage()
    {
        String templ = "templates/index.cs";
        String filename = "docs/index.html";

        data.setValue("A.B.C", "1");
        data.setValue("A.B.D", "2");
    }
    */

    public static ArrayList<String> hdfFiles = new ArrayList<String>();

    private static ArrayList<String> mTemplateDirs = new ArrayList<String>();
    private static boolean mTemplateDirSet = false;

    public static String outputDir = "docs";
    public static List<String> htmlDirs = new ArrayList<String>();
    public static String toroot = null;

    public static void addTemplateDir(String dir)
    {
        mTemplateDirSet = true;
        mTemplateDirs.add(dir);

        File hdfFile = new File(dir, "data.hdf");
        if (hdfFile.canRead()) {
            hdfFiles.add(hdfFile.getPath());
        }
    }

    private static int countSlashes(String s)
    {
        final int N = s.length();
        int slashcount = 0;
        for (int i=0; i<N; i++) {
            if (s.charAt(i) == '/') {
                slashcount++;
            }
        }
        return slashcount;
    }

    public static void write(HDF data, String templ, String filename)
    {
        write(data, templ, filename, false);
    }

    public static void write(HDF data, String templ, String filename, boolean fullPath)
    {
        if (!htmlDirs.isEmpty()) {
            data.setValue("hasindex", "true");
        }

        String toroot;
        if (ClearPage.toroot != null) {
            toroot = ClearPage.toroot;
        } else {
            int slashcount = countSlashes(filename);
            if (slashcount > 0) {
                toroot = "";
                for (int i=0; i<slashcount; i++) {
                    toroot += "../";
                }
            } else {
                toroot = "./";
            }
        }
        data.setValue("toroot", toroot);

        data.setValue("filename", filename);

        if (!fullPath) {
            filename = outputDir + "/" + filename;
        }

        int i=0;
        if (!htmlDirs.isEmpty()) {
            for (String dir : htmlDirs) {
                data.setValue("hdf.loadpaths." + i, dir);
                i++;
            }
        }
        if (mTemplateDirSet) {
            for (String dir: mTemplateDirs) {
                data.setValue("hdf.loadpaths." + i, dir);
                i++;
            }
        } else {
            data.setValue("hdf.loadpaths." + i, "templates");
        }
        
        CS cs = new CS(data);
        cs.parseFile(templ);

        File file = new File(outputFilename(filename));
        
        ensureDirectory(file);

        OutputStreamWriter stream = null;
        try {
            stream = new OutputStreamWriter(
                            new FileOutputStream(file), "UTF-8");
            String rendered = cs.render();
            stream.write(rendered, 0, rendered.length());
        }
        catch (IOException e) {
            System.out.println("error: " + e.getMessage() + "; when writing file: " + filename);
        }
        finally {
            if (stream != null) {
                try {
                    stream.close();
                }
                catch (IOException e) {
                }
            }
        }
    }

    // recursively create the directories to the output
    public static void ensureDirectory(File f)
    {
        File parent = f.getParentFile();
        if (parent != null) {
            parent.mkdirs();
        }
    }

    public static void copyFile(File from, String toPath)
    {
        File to = new File(outputDir + "/" + toPath);
        FileInputStream in;
        FileOutputStream out;
        try {
            if (!from.exists()) {
                throw new IOException();
            }
            in = new FileInputStream(from);
        }
        catch (IOException e) {
            System.err.println(from.getAbsolutePath() + ": Error opening file");
            return ;
        }
        ensureDirectory(to);
        try {
            out = new FileOutputStream(to);
        }
        catch (IOException e) {
            System.err.println(from.getAbsolutePath() + ": Error opening file");
            return ;
        }

        long sizel = from.length();
        final int maxsize = 64*1024;
        int size = sizel > maxsize ? maxsize : (int)sizel;
        byte[] buf = new byte[size];
        while (true) {
            try {
                size = in.read(buf);
            }
            catch (IOException e) {
                System.err.println(from.getAbsolutePath()
                        + ": error reading file");
                break;
            }
            if (size > 0) {
                try {
                    out.write(buf, 0, size);
                }
                catch (IOException e) {
                    System.err.println(from.getAbsolutePath()
                        + ": error writing file");
                }
            } else {
                break;
            }
        }
        try {
            in.close();
        }
        catch (IOException e) {
        }
        try {
            out.close();
        }
        catch (IOException e) {
        }
    }
    
    /** Takes a string that ends w/ .html and changes the .html to htmlExtension */
    public static String outputFilename(String htmlFile) {
        if (!DroidDoc.htmlExtension.equals(".html") && htmlFile.endsWith(".html")) {
            return htmlFile.substring(0, htmlFile.length()-5) + DroidDoc.htmlExtension;
        } else {
            return htmlFile;
        }
    }

}
