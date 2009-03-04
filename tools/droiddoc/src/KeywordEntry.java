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

class KeywordEntry implements Comparable
{
    KeywordEntry(String label, String href, String comment)
    {
        this.label = label;
        this.href = href;
        this.comment = comment;
    }

    public void makeHDF(HDF data, String base)
    {
        data.setValue(base + ".label", this.label);
        data.setValue(base + ".href", this.href);
        data.setValue(base + ".comment", this.comment);
    }

    public char firstChar()
    {
        return Character.toUpperCase(this.label.charAt(0));
    }

    public int compareTo(Object that)
    {
        return this.label.compareToIgnoreCase(((KeywordEntry)that).label);
    }

    private String label;
    private String href;
    private String comment;
}


