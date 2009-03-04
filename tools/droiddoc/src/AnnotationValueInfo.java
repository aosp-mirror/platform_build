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

public class AnnotationValueInfo
{
    private Object mValue;
    private String mString;
    private MethodInfo mElement;

    public AnnotationValueInfo(MethodInfo element)
    {
        mElement = element;
    }

    public void init(Object value)
    {
        mValue = value;
    }

    public MethodInfo element()
    {
        return mElement;
    }

    public Object value()
    {
        return mValue;
    }

    public String valueString()
    {
        Object v = mValue;
        if (v instanceof TypeInfo) {
            return ((TypeInfo)v).fullName();
        }
        else if (v instanceof FieldInfo) {
            StringBuilder str = new StringBuilder();
            FieldInfo f = (FieldInfo)v;
            str.append(f.containingClass().qualifiedName());
            str.append('.');
            str.append(f.name());
            return str.toString();
        }
        else if (v instanceof AnnotationInstanceInfo) {
            return v.toString();
        }
        else if (v instanceof AnnotationValueInfo[]) {
            StringBuilder str = new StringBuilder();
            AnnotationValueInfo[] array = (AnnotationValueInfo[])v;
            final int N = array.length;
            str.append("{");
            for (int i=0; i<array.length; i++) {
                str.append(array[i].valueString());
                if (i != N-1) {
                    str.append(",");
                }
            }
            str.append("}");
            return str.toString();
        }
        else {
            return FieldInfo.constantLiteralValue(v);
        }
    }
}

