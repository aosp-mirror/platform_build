#
# Copyright (C) 2007 The Android Open Source Project
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

_device_var_list := \
    DEVICE_NAME \
    DEVICE_BOARD \
    DEVICE_REGION

define dump-device
$(info ==== $(1) ====)\
$(foreach v,$(_device_var_list),\
$(info DEVICES.$(1).$(v) := $(DEVICES.$(1).$(v))))\
$(info --------)
endef

define dump-devices
$(foreach p,$(DEVICES),$(call dump-device,$(p)))
endef

#
# $(1): device to inherit
#
define inherit-device
  $(foreach v,$(_device_var_list), \
      $(eval $(v) := $($(v)) $(INHERIT_TAG)$(strip $(1))))
endef

#
# $(1): device makefile list
#
#TODO: check to make sure that devices have all the necessary vars defined
define import-devices
$(call import-nodes,DEVICES,$(1),$(_device_var_list))
endef


#
# $(1): short device name like "sooner"
#
define _resolve-short-device-name
  $(eval dn := $(strip $(1)))
  $(eval d := \
      $(foreach d,$(DEVICES), \
          $(if $(filter $(dn),$(DEVICES.$(d).DEVICE_NAME)), \
            $(d) \
       )) \
   )
  $(eval d := $(sort $(d)))
  $(if $(filter 1,$(words $(d))), \
    $(d), \
    $(if $(filter 0,$(words $(d))), \
      $(error No matches for device "$(dn)"), \
      $(error Device "$(dn)" ambiguous: matches $(d)) \
    ) \
  )
endef

#
# $(1): short device name like "sooner"
#
define resolve-short-device-name
$(strip $(call _resolve-short-device-name,$(1)))
endef
