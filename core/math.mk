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

###########################################################
# Basic math functions for non-negative integers <= 100
#
# (SDK versions for example)
###########################################################
__MATH_POS_NUMBERS :=  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 \
                      21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 \
                      41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 \
                      61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 \
                      81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100
__MATH_NUMBERS := 0 $(__MATH_POS_NUMBERS)

math-error = $(call pretty-error,$(1))
math-expect :=
math-expect-true :=
math-expect :=
math-expect-error :=

# Run the math tests with:
#  make -f ${ANDROID_BUILD_TOP}/build/make/core/math.mk RUN_MATH_TESTS=true
#  $(get_build_var CKATI) -f ${ANDROID_BUILD_TOP}//build/make/core/math.mk RUN_MATH_TESTS=true
ifdef RUN_MATH_TESTS
  MATH_TEST_FAILURE :=
  MATH_TEST_ERROR :=
  math-error = $(if $(MATH_TEST_ERROR),,$(eval MATH_TEST_ERROR:=$(1)))
  define math-expect
    $(eval got:=$$$1) \
    $(if $(subst $(got),,$(2))$(subst $(2),,$(got))$(MATH_TEST_ERROR), \
      $(if $(MATH_TEST_ERROR),$(warning $(MATH_TEST_ERROR)),$(warning $$$1 '$(got)' != '$(2)')) \
      $(eval MATH_TEST_FAILURE := true)) \
    $(eval MATH_TEST_ERROR :=) \
    $(eval got:=)
  endef
  math-expect-true = $(call math-expect,$(1),true)
  math-expect-false = $(call math-expect,$(1),)

  define math-expect-error
    $(eval got:=$$$1) \
    $(if $(subst $(MATH_TEST_ERROR),,$(2))$(subst $(2),,$(MATH_TEST_ERROR)), \
      $(warning '$(MATH_TEST_ERROR)' != '$(2)') \
      $(eval MATH_TEST_FAILURE := true)) \
    $(eval MATH_TEST_ERROR :=) \
    $(eval got:=)
  endef
endif

# Returns true if $(1) is a non-negative integer <= 100, otherwise returns nothing.
define math_is_number
$(strip \
  $(if $(1),,$(call math-error,Argument missing)) \
  $(if $(word 2,$(1)),$(call math-error,Multiple words in a single argument: $(1))) \
  $(if $(filter $(1),$(__MATH_NUMBERS)),true))
endef

define math_is_zero
$(strip \
  $(if $(word 2,$(1)),$(call math-error,Multiple words in a single argument: $(1))) \
  $(if $(filter 0,$(1)),true))
endef

$(call math-expect-true,(call math_is_number,0))
$(call math-expect-true,(call math_is_number,2))
$(call math-expect-false,(call math_is_number,foo))
$(call math-expect-false,(call math_is_number,-1))
$(call math-expect-error,(call math_is_number,1 2),Multiple words in a single argument: 1 2)
$(call math-expect-error,(call math_is_number,no 2),Multiple words in a single argument: no 2)

$(call math-expect-true,(call math_is_zero,0))
$(call math-expect-false,(call math_is_zero,1))
$(call math-expect-false,(call math_is_zero,foo))
$(call math-expect-error,(call math_is_zero,1 2),Multiple words in a single argument: 1 2)
$(call math-expect-error,(call math_is_zero,no 2),Multiple words in a single argument: no 2)

define _math_check_valid
$(if $(call math_is_number,$(1)),,$(call math-error,Only non-negative integers <= 100 are supported (not $(1))))
endef

$(call math-expect,(call _math_check_valid,0))
$(call math-expect,(call _math_check_valid,1))
$(call math-expect,(call _math_check_valid,100))
$(call math-expect-error,(call _math_check_valid,-1),Only non-negative integers <= 100 are supported (not -1))
$(call math-expect-error,(call _math_check_valid,101),Only non-negative integers <= 100 are supported (not 101))
$(call math-expect-error,(call _math_check_valid,),Argument missing)
$(call math-expect-error,(call _math_check_valid,1 2),Multiple words in a single argument: 1 2)

# return a list containing integers ranging from [$(1),$(2)]
define int_range_list
$(strip \
  $(call _math_check_valid,$(1))$(call _math_check_valid,$(2)) \
  $(if $(call math_is_zero,$(1)),0)\
  $(wordlist $(if $(call math_is_zero,$(1)),1,$(1)),$(2),$(__MATH_POS_NUMBERS)))
endef

$(call math-expect,(call int_range_list,0,1),0 1)
$(call math-expect,(call int_range_list,1,1),1)
$(call math-expect,(call int_range_list,1,2),1 2)
$(call math-expect,(call int_range_list,2,1),)
$(call math-expect-error,(call int_range_list,1,101),Only non-negative integers <= 100 are supported (not 101))


# Returns the greater of $1 or $2.
# If $1 or $2 is not a positive integer <= 100, then an error is generated.
define math_max
$(strip $(call _math_check_valid,$(1)) $(call _math_check_valid,$(2)) \
  $(lastword $(filter $(1) $(2),$(__MATH_NUMBERS))))
endef

$(call math-expect-error,(call math_max),Argument missing)
$(call math-expect-error,(call math_max,1),Argument missing)
$(call math-expect-error,(call math_max,1 2,3),Multiple words in a single argument: 1 2)
$(call math-expect,(call math_max,0,1),1)
$(call math-expect,(call math_max,1,0),1)
$(call math-expect,(call math_max,1,1),1)
$(call math-expect,(call math_max,5,42),42)
$(call math-expect,(call math_max,42,5),42)

define math_gt_or_eq
$(if $(filter $(1),$(call math_max,$(1),$(2))),true)
endef

define math_lt
$(if $(call math_gt_or_eq,$(1),$(2)),,true)
endef

$(call math-expect-true,(call math_gt_or_eq, 2, 1))
$(call math-expect-true,(call math_gt_or_eq, 1, 1))
$(call math-expect-false,(call math_gt_or_eq, 1, 2))

# $1 is the variable name to increment
define inc_and_print
$(strip $(eval $(1) := $($(1)) .)$(words $($(1))))
endef

ifdef RUN_MATH_TESTS
a :=
$(call math-expect,(call inc_and_print,a),1)
$(call math-expect,(call inc_and_print,a),2)
$(call math-expect,(call inc_and_print,a),3)
$(call math-expect,(call inc_and_print,a),4)
endif

# Returns the words in $2 that are numbers and are less than $1
define numbers_less_than
$(strip \
  $(foreach n,$2, \
    $(if $(call math_is_number,$(n)), \
      $(if $(call math_lt,$(n),$(1)), \
        $(n)))))
endef

$(call math-expect,(call numbers_less_than,0,0 1 2 3),)
$(call math-expect,(call numbers_less_than,1,0 2 1 3),0)
$(call math-expect,(call numbers_less_than,2,0 2 1 3),0 1)
$(call math-expect,(call numbers_less_than,3,0 2 1 3),0 2 1)
$(call math-expect,(call numbers_less_than,4,0 2 1 3),0 2 1 3)
$(call math-expect,(call numbers_less_than,3,0 2 1 3 2),0 2 1 2)

_INT_LIMIT_WORDS := $(foreach a,x x,$(foreach b,x x x x x x x x x x x x x x x x,\
  $(foreach c,x x x x x x x x x x x x x x x x,x x x x x x x x x x x x x x x x)))

define _int_encode
$(if $(filter $(words x $(_INT_LIMIT_WORDS)),$(words $(wordlist 1,$(1),x $(_INT_LIMIT_WORDS)))),\
  $(call math-error,integer greater than $(words $(_INT_LIMIT_WORDS)) is not supported!),\
    $(wordlist 1,$(1),$(_INT_LIMIT_WORDS)))
endef

# _int_max returns the maximum of the two arguments
# input: two (x) lists; output: one (x) list
# integer cannot be passed in directly. It has to be converted using _int_encode.
define _int_max
$(subst xx,x,$(join $(1),$(2)))
endef

# first argument is greater than second argument
# output: non-empty if true
# integer cannot be passed in directly. It has to be converted using _int_encode.
define _int_greater-than
$(filter-out $(words $(2)),$(words $(call _int_max,$(1),$(2))))
endef

# first argument equals to second argument
# output: non-empty if true
# integer cannot be passed in directly. It has to be converted using _int_encode.
define _int_equal
$(filter $(words $(1)),$(words $(2)))
endef

# first argument is greater than or equal to second argument
# output: non-empty if true
# integer cannot be passed in directly. It has to be converted using _int_encode.
define _int_greater-or-equal
$(call _int_greater-than,$(1),$(2))$(call _int_equal,$(1),$(2))
endef

define int_plus
$(words $(call _int_encode,$(1)) $(call _int_encode,$(2)))
endef

$(call math-expect,(call int_plus,0,0),0)
$(call math-expect,(call int_plus,0,1),1)
$(call math-expect,(call int_plus,1,0),1)
$(call math-expect,(call int_plus,1,100),101)
$(call math-expect,(call int_plus,100,100),200)

define int_subtract
$(strip \
  $(if $(call _int_greater-or-equal,$(call _int_encode,$(1)),$(call _int_encode,$(2))),\
  $(words $(filter-out xx,$(join $(call _int_encode,$(1)),$(call _int_encode,$(2))))),\
    $(call math-error,subtract underflow $(1) - $(2))))
endef

$(call math-expect,(call int_subtract,0,0),0)
$(call math-expect,(call int_subtract,1,0),1)
$(call math-expect,(call int_subtract,1,1),0)
$(call math-expect,(call int_subtract,100,1),99)
$(call math-expect,(call int_subtract,200,100),100)
$(call math-expect-error,(call int_subtract,0,1),subtract underflow 0 - 1)

define int_multiply
$(words $(foreach a,$(call _int_encode,$(1)),$(call _int_encode,$(2))))
endef

$(call math-expect,(call int_multiply,0,0),0)
$(call math-expect,(call int_multiply,1,0),0)
$(call math-expect,(call int_multiply,1,1),1)
$(call math-expect,(call int_multiply,100,1),100)
$(call math-expect,(call int_multiply,1,100),100)
$(call math-expect,(call int_multiply,4,100),400)
$(call math-expect,(call int_multiply,100,4),400)

define int_divide
$(if $(filter 0,$(2)),$(call math-error,division by zero is not allowed!),$(strip \
  $(if $(call _int_greater-or-equal,$(call _int_encode,$(1)),$(call _int_encode,$(2))), \
    $(call int_plus,$(call int_divide,$(call int_subtract,$(1),$(2)),$(2)),1),0)))
endef

$(call math-expect,(call int_divide,1,1),1)
$(call math-expect,(call int_divide,200,1),200)
$(call math-expect,(call int_divide,200,3),66)
$(call math-expect,(call int_divide,1,2),0)
$(call math-expect-error,(call int_divide,0,0),division by zero is not allowed!)
$(call math-expect-error,(call int_divide,1,0),division by zero is not allowed!)

ifdef RUN_MATH_TESTS
  ifdef MATH_TEST_FAILURE
    math-tests:
	@echo FAIL
	@false
  else
    math-tests:
	@echo PASS
  endif
  .PHONY: math-tests
endif
