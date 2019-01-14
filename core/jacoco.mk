#
# Copyright (C) 2017 The Android Open Source Project
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
#

# This file sets up Java code coverage via Jacoco
# This file is only intended to be included internally by the build system
# (at the time of authorship, it is included by java.mk and
# java_host_library.mk)

# determine Jacoco include/exclude filters even when coverage is not enabled
# to get syntax checking on LOCAL_JACK_COVERAGE_(INCLUDE|EXCLUDE)_FILTER
# copy filters from Jack but also skip some known java packages
my_include_filter := $(strip $(LOCAL_JACK_COVERAGE_INCLUDE_FILTER))
my_exclude_filter := $(strip $(DEFAULT_JACOCO_EXCLUDE_FILTER),$(LOCAL_JACK_COVERAGE_EXCLUDE_FILTER))

my_include_args := $(call jacoco-class-filter-to-file-args, $(my_include_filter))
my_exclude_args := $(call jacoco-class-filter-to-file-args, $(my_exclude_filter))

# single-quote each arg of the include args so the '*' gets evaluated by zip
# don't quote the exclude args they need to be evaluated by bash for rm -rf
my_include_args := $(foreach arg,$(my_include_args),'$(arg)')

ifeq ($(LOCAL_EMMA_INSTRUMENT),true)
  my_files := $(intermediates.COMMON)/jacoco

  # make a task that unzips the classes that we want to instrument from the
  # input jar
  my_unzipped_path := $(my_files)/work/classes-to-instrument/classes
  my_unzipped_timestamp_path := $(my_files)/work/classes-to-instrument/updated.stamp
$(my_unzipped_timestamp_path): PRIVATE_UNZIPPED_PATH := $(my_unzipped_path)
$(my_unzipped_timestamp_path): PRIVATE_UNZIPPED_TIMESTAMP_PATH := $(my_unzipped_timestamp_path)
$(my_unzipped_timestamp_path): PRIVATE_INCLUDE_ARGS := $(my_include_args)
$(my_unzipped_timestamp_path): PRIVATE_EXCLUDE_ARGS := $(my_exclude_args)
$(my_unzipped_timestamp_path): PRIVATE_FULL_CLASSES_PRE_JACOCO_JAR := $(LOCAL_FULL_CLASSES_PRE_JACOCO_JAR)
$(my_unzipped_timestamp_path): $(LOCAL_FULL_CLASSES_PRE_JACOCO_JAR)
	rm -rf $(PRIVATE_UNZIPPED_PATH) $@
	mkdir -p $(PRIVATE_UNZIPPED_PATH)
	unzip -q $(PRIVATE_FULL_CLASSES_PRE_JACOCO_JAR) \
	  -d $(PRIVATE_UNZIPPED_PATH) \
	  $(PRIVATE_INCLUDE_ARGS)
	(cd $(PRIVATE_UNZIPPED_PATH) && rm -rf $(PRIVATE_EXCLUDE_ARGS))
	(cd $(PRIVATE_UNZIPPED_PATH) && find -not -name "*.class" -type f -exec rm {} \;)
	touch $(PRIVATE_UNZIPPED_TIMESTAMP_PATH)
# Unfortunately in the previous task above,
# 'rm -rf $(PRIVATE_EXCLUDE_ARGS)' needs to be a separate
# shell command after 'unzip'.
# We can't just use the '-x' (exclude) option of 'unzip' because if both
# inclusions and exclusions are specified and an exclusion matches no
# inclusions, then 'unzip' exits with an error (error 11).
# We could ignore the error, but that would make the process less reliable


  # make a task that zips only the classes that will be instrumented
  # (for passing in to the report generator later)
  my_classes_to_report_on_path := $(my_files)/report-resources/jacoco-report-classes.jar
$(my_classes_to_report_on_path): PRIVATE_UNZIPPED_PATH := $(my_unzipped_path)
$(my_classes_to_report_on_path): $(my_unzipped_timestamp_path)
	rm -f $@
	zip -q $@ \
	  -r $(PRIVATE_UNZIPPED_PATH)



  # make a task that invokes instrumentation
  my_instrumented_path := $(my_files)/work/instrumented/classes
  my_instrumented_timestamp_path := $(my_files)/work/instrumented/updated.stamp
$(my_instrumented_timestamp_path): PRIVATE_INSTRUMENTED_PATH := $(my_instrumented_path)
$(my_instrumented_timestamp_path): PRIVATE_INSTRUMENTED_TIMESTAMP_PATH := $(my_instrumented_timestamp_path)
$(my_instrumented_timestamp_path): PRIVATE_UNZIPPED_PATH := $(my_unzipped_path)
$(my_instrumented_timestamp_path): $(my_unzipped_timestamp_path) $(JACOCO_CLI_JAR)
	rm -rf $(PRIVATE_INSTRUMENTED_PATH)
	mkdir -p $(PRIVATE_INSTRUMENTED_PATH)
	java -jar $(JACOCO_CLI_JAR) \
	  instrument \
	  --quiet \
	  --dest '$(PRIVATE_INSTRUMENTED_PATH)' \
	  $(PRIVATE_UNZIPPED_PATH)
	touch $(PRIVATE_INSTRUMENTED_TIMESTAMP_PATH)


  # make a task that zips both the instrumented classes and the uninstrumented
  # classes (this jar is the instrumented application to execute)
  my_temp_jar_path := $(my_files)/work/usable.jar
  LOCAL_FULL_CLASSES_JACOCO_JAR := $(intermediates.COMMON)/classes-jacoco.jar
$(LOCAL_FULL_CLASSES_JACOCO_JAR): PRIVATE_TEMP_JAR_PATH := $(my_temp_jar_path)
$(LOCAL_FULL_CLASSES_JACOCO_JAR): PRIVATE_INSTRUMENTED_PATH := $(my_instrumented_path)
$(LOCAL_FULL_CLASSES_JACOCO_JAR): PRIVATE_FULL_CLASSES_PRE_JACOCO_JAR := $(LOCAL_FULL_CLASSES_PRE_JACOCO_JAR)
$(LOCAL_FULL_CLASSES_JACOCO_JAR): $(JAR_ARGS)
$(LOCAL_FULL_CLASSES_JACOCO_JAR): $(my_instrumented_timestamp_path) $(LOCAL_FULL_CLASSES_PRE_JACOCO_JAR)
	rm -f $@ $(PRIVATE_TEMP_JAR_PATH)
	# copy the pre-jacoco jar (containing files excluded from instrumentation)
	cp $(PRIVATE_FULL_CLASSES_PRE_JACOCO_JAR) $(PRIVATE_TEMP_JAR_PATH)
	# copy instrumented files back into the resultant jar
	$(JAR) -uf $(PRIVATE_TEMP_JAR_PATH) $(call jar-args-sorted-files-in-directory,$(PRIVATE_INSTRUMENTED_PATH))
	mv $(PRIVATE_TEMP_JAR_PATH) $@

  # this is used to trigger $(my_classes_to_report_on_path) to build
  # when $(LOCAL_FULL_CLASSES_JACOCO_JAR) builds, but it isn't truly a
  # dependency.
$(LOCAL_FULL_CLASSES_JACOCO_JAR): $(my_classes_to_report_on_path)

else # LOCAL_EMMA_INSTRUMENT != true
  LOCAL_FULL_CLASSES_JACOCO_JAR := $(LOCAL_FULL_CLASSES_PRE_JACOCO_JAR)
endif # LOCAL_EMMA_INSTRUMENT == true

LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_FULL_CLASSES_JACOCO_JAR)
