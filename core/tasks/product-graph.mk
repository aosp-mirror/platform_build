#
# Copyright (C) 2009 The Android Open Source Project
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

products_pdf := $(OUT_DIR)/products.pdf

# This rule doens't include any nodes that don't inherit from
# anything or don't have anything inherit from them, to make the
# graph more readable.  To add that, add this line to the rule
# below:
#		$(foreach p,$(ALL_PRODUCTS), echo \"$(p)\";) \

$(products_pdf):
	$(hide) ( \
		echo 'digraph {'; \
		echo 'graph [ ratio = .6, pack=false];'; \
		$(foreach p,$(ALL_PRODUCTS), \
			$(foreach d,$(PRODUCTS.$(strip $(p)).INHERITS_FROM), \
			echo \"$(d)\" -\> \"$(p)\";)) \
		echo '}' \
	) | dot -Tpdf -Nshape=box -o $@

product-graph: $(products_pdf)

