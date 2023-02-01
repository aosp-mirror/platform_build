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

# the sort also acts as a strip to remove the single space entries that creep in because of the evals
define gather-all-makefiles-for-current-product
$(eval _all_products_visited := )\
$(sort $(call gather-all-makefiles-for-current-product-inner,$(INTERNAL_PRODUCT)))
endef

define gather-all-makefiles-for-current-product-inner
	$(foreach p,$(1),\
		$(if $(filter $(p),$(_all_products_visited)),, \
			$(p) \
			$(eval _all_products_visited += $(p)) \
			$(call gather-all-makefiles-for-current-product-inner, $(PRODUCTS.$(strip $(p)).INHERITS_FROM))
		) \
	)
endef

node_color_target := orange
node_color_common := beige
node_color_vendor := lavenderblush
node_color_default := white
define node-color
$(if $(filter $(1),$(PRIVATE_TOP_LEVEL_MAKEFILE)),\
  $(node_color_target),\
  $(if $(filter build/make/target/product/%,$(1)),\
    $(node_color_common),\
    $(if $(filter vendor/%,$(1)),$(node_color_vendor),$(node_color_default))\
  )\
)
endef

open_parethesis := (
close_parenthesis := )

# Emit properties of a product node to a file.
# $(1) the product
# $(2) the output file
define emit-product-node-props
$(hide) echo \"$(1)\" [ \
label=\"$(dir $(1))\\n$(notdir $(1))$(if $(filter $(1),$(PRIVATE_TOP_LEVEL_MAKEFILE)),$(subst $(open_parethesis),,$(subst $(close_parenthesis),,\\n\\n$(PRODUCT_MODEL)\\n$(PRODUCT_DEVICE))))\" \
style=\"filled\" fillcolor=\"$(strip $(call node-color,$(1)))\" \
colorscheme=\"svg\" fontcolor=\"darkblue\" \
] >> $(2)

endef

products_graph := $(OUT_DIR)/products.dot

$(products_graph): PRIVATE_ALL_MAKEFILES_FOR_THIS_PRODUCT := $(call gather-all-makefiles-for-current-product)
$(products_graph): PRIVATE_TOP_LEVEL_MAKEFILE := $(INTERNAL_PRODUCT)
$(products_graph):
	@echo Product graph DOT: $@ for $(PRIVATE_TOP_LEVEL_MAKEFILE)
	$(hide) echo 'digraph {' > $@
	$(hide) echo 'graph [ ratio=.5 ];' >> $@
	$(hide) $(foreach p,$(PRIVATE_ALL_MAKEFILES_FOR_THIS_PRODUCT), \
	  $(foreach d,$(PRODUCTS.$(strip $(p)).INHERITS_FROM), echo \"$(d)\" -\> \"$(p)\" >> $@;))
	$(foreach p,$(PRIVATE_ALL_MAKEFILES_FOR_THIS_PRODUCT),$(call emit-product-node-props,$(p),$@))
	$(hide) echo '}' >> $@

.PHONY: product-graph
product-graph: $(products_graph)
	@echo Product graph .dot file: $(products_graph)
	@echo Command to convert to pdf: dot -Tpdf -Nshape=box -o $(OUT_DIR)/products.pdf $(products_graph)
	@echo Command to convert to svg: dot -Tsvg -Nshape=box -o $(OUT_DIR)/products.svg $(products_graph)
