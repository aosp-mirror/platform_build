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
products_graph := $(products_pdf:%.pdf=%.dot)
ifeq ($(strip $(ANDROID_PRODUCT_GRAPH)),)
products_list := $(INTERNAL_PRODUCT)
else
ifeq ($(strip $(ANDROID_PRODUCT_GRAPH)),--all)
products_list := --all
else
products_list := $(foreach prod,$(ANDROID_PRODUCT_GRAPH),$(call resolve-short-product-name,$(prod)))
endif
endif

$(products_graph): PRIVATE_PRODUCTS := $(products_list)

$(products_graph):
	@echo Product graph DOT: $@ for $(PRIVATE_PRODUCTS)
	$(hide) ( \
		echo 'digraph {'; \
		echo 'graph [ ratio=.5 ];'; \
		$(foreach p,$(ALL_PRODUCTS), \
			$(foreach d,$(PRODUCTS.$(strip $(p)).INHERITS_FROM), \
			echo \"$(d)\" -\> \"$(p)\";)) \
		$(foreach prod, \
			$(sort $(foreach p,$(ALL_PRODUCTS), \
				$(foreach d,$(PRODUCTS.$(strip $(p)).INHERITS_FROM), $(d))) \
				$(foreach p,$(ALL_PRODUCTS),$(p))), \
			echo \"$(prod)\" [ \
					label=\"$(dir $(prod))\\n$(notdir $(prod))\\n\\n$(PRODUCTS.$(strip $(prod)).PRODUCT_MODEL)\\n$(PRODUCTS.$(strip $(prod)).PRODUCT_DEVICE)\" \
					$(if $(filter $(prod),$(PRIVATE_PRODUCTS)), \
						style=\"filled\" fillcolor=\"#FFFDB0\",) \
				];) \
		echo '}' \
	) \
	| ./build/tools/filter-product-graph.py $(PRIVATE_PRODUCTS) \
	> $@

# This rule doesn't include any nodes that don't inherit from
# anything or don't have anything inherit from them, to make the
# graph more readable.  To add that, add this line to the rule
# below:
#		$(foreach p,$(ALL_PRODUCTS), echo \"$(p)\";) \

$(products_pdf): $(products_graph)
	@echo Product graph PDF: $@
	dot -Tpdf -Nshape=box -o $@ $<

product-graph: $(products_pdf)

