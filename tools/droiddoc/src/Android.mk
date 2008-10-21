# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := docs

LOCAL_SRC_FILES := \
    AnnotationInstanceInfo.java \
    AnnotationValueInfo.java \
	AttributeInfo.java \
	AttrTagInfo.java \
	ClassInfo.java \
	DroidDoc.java \
	ClearPage.java \
	Comment.java \
	ContainerInfo.java \
	Converter.java \
	DocFile.java \
	DocInfo.java \
	Errors.java \
	FieldInfo.java \
	Hierarchy.java \
	InheritedTags.java \
	KeywordEntry.java \
    LinkReference.java \
	LiteralTagInfo.java \
	MemberInfo.java \
	MethodInfo.java \
	PackageInfo.java \
	ParamTagInfo.java \
	ParameterInfo.java \
	ParsedTagInfo.java \
	Proofread.java \
	SampleCode.java \
	SampleTagInfo.java \
    Scoped.java \
	SeeTagInfo.java \
	Sorter.java \
	SourcePositionInfo.java \
    Stubs.java \
	TagInfo.java \
    TextTagInfo.java \
	ThrowsTagInfo.java \
	TodoFile.java \
	TypeInfo.java

LOCAL_JAVA_LIBRARIES := \
	clearsilver

LOCAL_CLASSPATH := \
	$(HOST_JDK_TOOLS_JAR)

LOCAL_MODULE:= droiddoc

include $(BUILD_HOST_JAVA_LIBRARY)
