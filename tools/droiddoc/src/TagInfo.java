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

public class TagInfo
{
    private String mName;
    private String mText;
    private String mKind;
    private SourcePositionInfo mPosition;

    TagInfo(String n, String k, String t, SourcePositionInfo sp)
    {
        mName = n;
        mText = t;
        mKind = k;
        mPosition = sp;
    }

    String name()
    {
        return mName;
    }

    String text()
    {
        return mText;
    }

    String kind()
    {
        return mKind;
    }
    
    SourcePositionInfo position() {
        return mPosition;
    }

    void setKind(String kind) {
        mKind = kind;
    }

    public void makeHDF(HDF data, String base)
    {
        data.setValue(base + ".name", name());
        data.setValue(base + ".text", text());
        data.setValue(base + ".kind", kind());
    }

    public static void makeHDF(HDF data, String base, TagInfo[] tags)
    {
        makeHDF(data, base, tags, null, 0, 0);
    }

    public static void makeHDF(HDF data, String base, InheritedTags tags)
    {
        makeHDF(data, base, tags.tags(), tags.inherited(), 0, 0);
    }

    private static int makeHDF(HDF data, String base, TagInfo[] tags,
                                InheritedTags inherited, int j, int depth)
    {
        int i;
        int len = tags.length;
        if (len == 0 && inherited != null) {
            j = makeHDF(data, base, inherited.tags(), inherited.inherited(), j, depth+1);
        } else {
            for (i=0; i<len; i++, j++) {
                TagInfo t = tags[i];
                if (inherited != null && t.name().equals("@inheritDoc")) {
                    j = makeHDF(data, base, inherited.tags(),
                                    inherited.inherited(), j, depth+1);
                } else {
                    if (t.name().equals("@inheritDoc")) {
                        Errors.error(Errors.BAD_INHERITDOC, t.mPosition,
                                "@inheritDoc on class/method that is not inherited");
                    }
                    t.makeHDF(data, base + "." + j);
                }
            }
        }
        return j;
    }
}

