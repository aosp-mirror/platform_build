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
import java.util.HashSet;

public class ParameterInfo
{
    ParameterInfo(String name, String typeName, TypeInfo type, SourcePositionInfo position)
    {
        mName = name;
        mTypeName = typeName;
        mType = type;
        mPosition = position;
    }

    TypeInfo type()
    {
        return mType;
    }

    String name()
    {
        return mName;
    }

    String typeName()
    {
        return mTypeName;
    }

    SourcePositionInfo position()
    {
        return mPosition;
    }

    public void makeHDF(HDF data, String base, boolean isLastVararg,
            HashSet<String> typeVariables)
    {
        data.setValue(base + ".name", this.name());
        type().makeHDF(data, base + ".type", isLastVararg, typeVariables);
    }

    public static void makeHDF(HDF data, String base, ParameterInfo[] params,
            boolean isVararg, HashSet<String> typeVariables)
    {
        for (int i=0; i<params.length; i++) {
            params[i].makeHDF(data, base + "." + i,
                    isVararg && (i == params.length - 1), typeVariables);
        }
    }
    
    String mName;
    String mTypeName;
    TypeInfo mType;
    SourcePositionInfo mPosition;
}

