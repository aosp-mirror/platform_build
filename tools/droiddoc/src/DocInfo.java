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

public abstract class DocInfo
{
    public DocInfo(String rawCommentText, SourcePositionInfo sp)
    {
        mRawCommentText = rawCommentText;
        mPosition = sp;
    }

    public boolean isHidden()
    {
        return comment().isHidden();
    }

    public boolean isDocOnly() {
        return comment().isDocOnly();
    }
    
    public String getRawCommentText()
    {
        return mRawCommentText;
    }

    public Comment comment()
    {
        if (mComment == null) {
            mComment = new Comment(mRawCommentText, parent(), mPosition);
        }
        return mComment;
    }

    public SourcePositionInfo position()
    {
        return mPosition;
    }

    public abstract ContainerInfo parent();

    public void setSince(String since) {
        mSince = since;
    }

    public String getSince() {
        return mSince;
    }

    private String mRawCommentText;
    Comment mComment;
    SourcePositionInfo mPosition;
    private String mSince;
}

