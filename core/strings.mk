#
# Copyright (C) 2018 The Android Open Source Project
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

###########################################################
## Convert to lower case without requiring a shell, which isn't cacheable.
##
## $(1): string
###########################################################
to-lower=$(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$1))))))))))))))))))))))))))

###########################################################
## Convert to upper case without requiring a shell, which isn't cacheable.
##
## $(1): string
###########################################################
to-upper=$(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$1))))))))))))))))))))))))))

# Sanity-check to-lower and to-upper
lower := abcdefghijklmnopqrstuvwxyz-_
upper := ABCDEFGHIJKLMNOPQRSTUVWXYZ-_

ifneq ($(lower),$(call to-lower,$(upper)))
  $(error to-lower sanity check failure)
endif

ifneq ($(upper),$(call to-upper,$(lower)))
  $(error to-upper sanity check failure)
endif

lower :=
upper :=

###########################################################
## Returns true if $(1) and $(2) are equal.  Returns
## the empty string if they are not equal.
###########################################################
define streq
$(strip $(if $(strip $(1)),\
  $(if $(strip $(2)),\
    $(if $(filter-out __,_$(subst $(strip $(1)),,$(strip $(2)))$(subst $(strip $(2)),,$(strip $(1)))_),,true), \
    ),\
  $(if $(strip $(2)),\
    ,\
    true)\
 ))
endef

###########################################################
## Convert "a b c" into "a:b:c"
###########################################################
define normalize-path-list
$(subst $(space),:,$(strip $(1)))
endef

###########################################################
## Convert "a b c" into "a,b,c"
###########################################################
define normalize-comma-list
$(subst $(space),$(comma),$(strip $(1)))
endef

###########################################################
## Read the word out of a colon-separated list of words.
## This has the same behavior as the built-in function
## $(word n,str).
##
## The individual words may not contain spaces.
##
## $(1): 1 based index
## $(2): value of the form a:b:c...
###########################################################

define word-colon
$(word $(1),$(subst :,$(space),$(2)))
endef

###########################################################
## Convert "a=b c= d e = f" into "a=b c=d e=f"
##
## $(1): list to collapse
## $(2): if set, separator word; usually "=", ":", or ":="
##       Defaults to "=" if not set.
###########################################################

define collapse-pairs
$(eval _cpSEP := $(strip $(if $(2),$(2),=)))\
$(strip $(subst $(space)$(_cpSEP)$(space),$(_cpSEP),$(strip \
    $(subst $(_cpSEP), $(_cpSEP) ,$(1)))$(space)))
endef

###########################################################
## Given a list of pairs, if multiple pairs have the same
## first components, keep only the first pair.
##
## $(1): list of pairs
## $(2): the separator word, such as ":", "=", etc.
define uniq-pairs-by-first-component
$(eval _upbfc_fc_set :=)\
$(strip $(foreach w,$(1), $(eval _first := $(word 1,$(subst $(2),$(space),$(w))))\
    $(if $(filter $(_upbfc_fc_set),$(_first)),,$(w)\
        $(eval _upbfc_fc_set += $(_first)))))\
$(eval _upbfc_fc_set :=)\
$(eval _first:=)
endef
