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

# the foreach and the if remove the single space entries that creep in because of the evals
define gather-all-products
$(sort $(foreach p, \
	$(eval _all_products_visited := )
  $(call all-products-inner, $(PARENT_PRODUCT_FILES)) \
	, $(if $(strip $(p)),$(strip $(p)),)) \
)
endef

define all-products-inner
	$(foreach p,$(1),\
		$(if $(filter $(p),$(_all_products_visited)),, \
			$(p) \
			$(eval _all_products_visited += $(p)) \
			$(call all-products-inner, $(PRODUCTS.$(strip $(p)).INHERITS_FROM))
		) \
	)
endef

this_makefile := build/make/core/product-graph.mk

products_graph := $(OUT_DIR)/products.dot
ifeq ($(strip $(ANDROID_PRODUCT_GRAPH)),)
products_list := $(INTERNAL_PRODUCT)
else
ifeq ($(strip $(ANDROID_PRODUCT_GRAPH)),--all)
products_list := --all
else
products_list := $(foreach prod,$(ANDROID_PRODUCT_GRAPH),$(call resolve-short-product-name,$(prod)))
endif
endif

all_products := $(call gather-all-products)

open_parethesis := (
close_parenthesis := )

node_color_target := orange
node_color_common := beige
node_color_vendor := lavenderblush
node_color_default := white
define node-color
$(if $(filter $(1),$(PRIVATE_PRODUCTS_FILTER)),\
  $(node_color_target),\
  $(if $(filter build/make/target/product/%,$(1)),\
    $(node_color_common),\
    $(if $(filter vendor/%,$(1)),$(node_color_vendor),$(node_color_default))\
  )\
)
endef

# Emit properties of a product node to a file.
# $(1) the product
# $(2) the output file
define emit-product-node-props
$(hide) echo \"$(1)\" [ \
label=\"$(dir $(1))\\n$(notdir $(1))\\n\\n$(subst $(close_parenthesis),,$(subst $(open_parethesis),,$(call get-product-var,$(1),PRODUCT_MODEL)))\\n$(call get-product-var,$(1),PRODUCT_DEVICE)\" \
style=\"filled\" fillcolor=\"$(strip $(call node-color,$(1)))\" \
colorscheme=\"svg\" fontcolor=\"darkblue\" href=\"products/$(1).html\" \
] >> $(2)

endef

$(products_graph): PRIVATE_PRODUCTS := $(all_products)
$(products_graph): PRIVATE_PRODUCTS_FILTER := $(products_list)

$(products_graph): $(this_makefile)
	@echo Product graph DOT: $@ for $(PRIVATE_PRODUCTS_FILTER)
	$(hide) echo 'digraph {' > $@.in
	$(hide) echo 'graph [ ratio=.5 ];' >> $@.in
	$(hide) $(foreach p,$(PRIVATE_PRODUCTS), \
	  $(foreach d,$(PRODUCTS.$(strip $(p)).INHERITS_FROM), echo \"$(d)\" -\> \"$(p)\" >> $@.in;))
	$(foreach p,$(PRIVATE_PRODUCTS),$(call emit-product-node-props,$(p),$@.in))
	$(hide) echo '}' >> $@.in
	$(hide) build/make/tools/filter-product-graph.py $(PRIVATE_PRODUCTS_FILTER) < $@.in > $@

# Evaluates to the name of the product file
# $(1) product file
define product-debug-filename
$(OUT_DIR)/products/$(strip $(1)).html
endef

# Makes a rule for the product debug info
# $(1) product file
define transform-product-debug
$(OUT_DIR)/products/$(strip $(1)).txt: $(this_makefile)
	@echo Product debug info file: $$@
	$(hide) rm -f $$@
	$(hide) mkdir -p $$(dir $$@)
	$(hide) echo 'FILE=$(strip $(1))' >> $$@
	$(hide) echo 'PRODUCT_NAME=$(call get-product-var,$(1),PRODUCT_NAME)' >> $$@
	$(hide) echo 'PRODUCT_MODEL=$(call get-product-var,$(1),PRODUCT_MODEL)' >> $$@
	$(hide) echo 'PRODUCT_LOCALES=$(call get-product-var,$(1),PRODUCT_LOCALES)' >> $$@
	$(hide) echo 'PRODUCT_AAPT_CONFIG=$(call get-product-var,$(1),PRODUCT_AAPT_CONFIG)' >> $$@
	$(hide) echo 'PRODUCT_AAPT_PREF_CONFIG=$(call get-product-var,$(1),PRODUCT_AAPT_PREF_CONFIG)' >> $$@
	$(hide) echo 'PRODUCT_PACKAGES=$(call get-product-var,$(1),PRODUCT_PACKAGES)' >> $$@
	$(hide) echo 'PRODUCT_DEVICE=$(call get-product-var,$(1),PRODUCT_DEVICE)' >> $$@
	$(hide) echo 'PRODUCT_MANUFACTURER=$(call get-product-var,$(1),PRODUCT_MANUFACTURER)' >> $$@
	$(hide) echo 'PRODUCT_PROPERTY_OVERRIDES=$(call get-product-var,$(1),PRODUCT_PROPERTY_OVERRIDES)' >> $$@
	$(hide) echo 'PRODUCT_DEFAULT_PROPERTY_OVERRIDES=$(call get-product-var,$(1),PRODUCT_DEFAULT_PROPERTY_OVERRIDES)' >> $$@
	$(hide) echo 'PRODUCT_SYSTEM_DEFAULT_PROPERTIES=$(call get-product-var,$(1),PRODUCT_SYSTEM_DEFAULT_PROPERTIES)' >> $$@
	$(hide) echo 'PRODUCT_PRODUCT_PROPERTIES=$(call get-product-var,$(1),PRODUCT_PRODUCT_PROPERTIES)' >> $$@
	$(hide) echo 'PRODUCT_SYSTEM_EXT_PROPERTIES=$(call get-product-var,$(1),PRODUCT_SYSTEM_EXT_PROPERTIES)' >> $$@
	$(hide) echo 'PRODUCT_ODM_PROPERTIES=$(call get-product-var,$(1),PRODUCT_ODM_PROPERTIES)' >> $$@
	$(hide) echo 'PRODUCT_CHARACTERISTICS=$(call get-product-var,$(1),PRODUCT_CHARACTERISTICS)' >> $$@
	$(hide) echo 'PRODUCT_COPY_FILES=$(call get-product-var,$(1),PRODUCT_COPY_FILES)' >> $$@
	$(hide) echo 'PRODUCT_OTA_PUBLIC_KEYS=$(call get-product-var,$(1),PRODUCT_OTA_PUBLIC_KEYS)' >> $$@
	$(hide) echo 'PRODUCT_EXTRA_RECOVERY_KEYS=$(call get-product-var,$(1),PRODUCT_EXTRA_RECOVERY_KEYS)' >> $$@
	$(hide) echo 'PRODUCT_PACKAGE_OVERLAYS=$(call get-product-var,$(1),PRODUCT_PACKAGE_OVERLAYS)' >> $$@
	$(hide) echo 'DEVICE_PACKAGE_OVERLAYS=$(call get-product-var,$(1),DEVICE_PACKAGE_OVERLAYS)' >> $$@
	$(hide) echo 'PRODUCT_SDK_ADDON_NAME=$(call get-product-var,$(1),PRODUCT_SDK_ADDON_NAME)' >> $$@
	$(hide) echo 'PRODUCT_SDK_ADDON_COPY_FILES=$(call get-product-var,$(1),PRODUCT_SDK_ADDON_COPY_FILES)' >> $$@
	$(hide) echo 'PRODUCT_SDK_ADDON_COPY_MODULES=$(call get-product-var,$(1),PRODUCT_SDK_ADDON_COPY_MODULES)' >> $$@
	$(hide) echo 'PRODUCT_SDK_ADDON_DOC_MODULES=$(call get-product-var,$(1),PRODUCT_SDK_ADDON_DOC_MODULES)' >> $$@
	$(hide) echo 'PRODUCT_DEFAULT_WIFI_CHANNELS=$(call get-product-var,$(1),PRODUCT_DEFAULT_WIFI_CHANNELS)' >> $$@
	$(hide) echo 'PRODUCT_DEFAULT_DEV_CERTIFICATE=$(call get-product-var,$(1),PRODUCT_DEFAULT_DEV_CERTIFICATE)' >> $$@
	$(hide) echo 'PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES=$(call get-product-var,$(1),PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES)' >> $$@
	$(hide) echo 'PRODUCT_RESTRICT_VENDOR_FILES=$(call get-product-var,$(1),PRODUCT_RESTRICT_VENDOR_FILES)' >> $$@
	$(hide) echo 'PRODUCT_VENDOR_KERNEL_HEADERS=$(call get-product-var,$(1),PRODUCT_VENDOR_KERNEL_HEADERS)' >> $$@

$(call product-debug-filename, $(p)): \
			$(OUT_DIR)/products/$(strip $(1)).txt \
			build/make/tools/product_debug.py \
			$(this_makefile)
	@echo Product debug html file: $$@
	$(hide) mkdir -p $$(dir $$@)
	$(hide) cat $$< | build/make/tools/product_debug.py > $$@
endef

product_debug_files:=
$(foreach p,$(all_products), \
			$(eval $(call transform-product-debug, $(p))) \
			$(eval product_debug_files += $(call product-debug-filename, $(p))) \
   )

.PHONY: product-graph
product-graph: $(products_graph)
	@echo Product graph .dot file: $(products_graph)
	@echo Command to convert to pdf: dot -Tpdf -Nshape=box -o $(OUT_DIR)/products.pdf $(products_graph)
	@echo Command to convert to svg: dot -Tsvg -Nshape=box -o $(OUT_DIR)/products.svg $(products_graph)
