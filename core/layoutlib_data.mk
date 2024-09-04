# Data files for layoutlib

FONT_TEMP := $(call intermediates-dir-for,PACKAGING,fonts,HOST,COMMON)

# The font configuration files - system_fonts.xml, fallback_fonts.xml etc.
font_config := $(sort $(wildcard frameworks/base/data/fonts/*.xml))
font_config := $(addprefix $(FONT_TEMP)/, $(notdir $(font_config)))

$(font_config): $(FONT_TEMP)/%.xml: \
			frameworks/base/data/fonts/%.xml
	$(hide) mkdir -p $(dir $@)
	$(hide) cp -vf $< $@

# List of fonts on the device that we want to ship. This is all .ttf, .ttc and .otf fonts.
fonts_device := $(filter $(TARGET_OUT)/fonts/%.ttf $(TARGET_OUT)/fonts/%.ttc $(TARGET_OUT)/fonts/%.otf, $(INTERNAL_SYSTEMIMAGE_FILES))
fonts_device := $(addprefix $(FONT_TEMP)/, $(notdir $(fonts_device)))

# TODO: If the font file is a symlink, reuse the font renamed from the symlink
# target.
$(fonts_device): $(FONT_TEMP)/%: $(TARGET_OUT)/fonts/%
	$(hide) mkdir -p $(dir $@)
	$(hide) cp -vf $< $@

KEYBOARD_TEMP := $(call intermediates-dir-for,PACKAGING,keyboards,HOST,COMMON)

# The key character map files needed for supporting KeyEvent
keyboards := $(sort $(wildcard frameworks/base/data/keyboards/*.kcm))
keyboards := $(addprefix $(KEYBOARD_TEMP)/, $(notdir $(keyboards)))

$(keyboards): $(KEYBOARD_TEMP)/%.kcm: frameworks/base/data/keyboards/%.kcm
	$(hide) mkdir -p $(dir $@)
	$(hide) cp -vf $< $@

# List of all data files - font files, font configuration files, key character map files
LAYOUTLIB_FILES := $(fonts_device) $(font_config) $(keyboards)

.PHONY: layoutlib layoutlib-tests
layoutlib layoutlib-tests: $(LAYOUTLIB_FILES)

$(call dist-for-goals, layoutlib, $(foreach m,$(fonts_device), $(m):layoutlib_native/fonts/$(notdir $(m))))
$(call dist-for-goals, layoutlib, $(foreach m,$(font_config), $(m):layoutlib_native/fonts/$(notdir $(m))))
$(call dist-for-goals, layoutlib, $(foreach m,$(keyboards), $(m):layoutlib_native/keyboards/$(notdir $(m))))

FONT_TEMP :=
font_config :=
fonts_device :=
FONT_FILES :=

# The following build process of build.prop, layoutlib-res.zip is moved here from release_layoutlib.sh
# so the SBOM of all platform neutral artifacts and Linux/Windows artifacts of layoutlib can be built in Make/Soong.
# See go/layoutlib-sbom.

# build.prop shipped with layoutlib
LAYOUTLIB_BUILD_PROP := $(call intermediates-dir-for,PACKAGING,layoutlib-build-prop,HOST,COMMON)
$(LAYOUTLIB_BUILD_PROP)/layoutlib-build.prop: $(INSTALLED_SDK_BUILD_PROP_TARGET)
	rm -rf $@
	cp $< $@
	# Remove all the uncommon build properties
	sed -i '/^ro\.\(build\|product\|config\|system\)/!d' $@
	# Mark the build as layoutlib. This can be read at runtime by apps
	sed -i 's|ro.product.brand=generic|ro.product.brand=studio|' $@
	sed -i 's|ro.product.device=generic|ro.product.device=layoutlib|' $@

$(call dist-for-goals,layoutlib,$(LAYOUTLIB_BUILD_PROP)/layoutlib-build.prop:layoutlib_native/build.prop)

# Resource files from frameworks/base/core/res/res
LAYOUTLIB_RES := $(call intermediates-dir-for,PACKAGING,layoutlib-res,HOST,COMMON)
LAYOUTLIB_RES_FILES := $(shell find frameworks/base/core/res/res -type f -not -path 'frameworks/base/core/res/res/values-m[nc]c*' | sort)
EMULATED_OVERLAYS_FILES := $(shell find frameworks/base/packages/overlays/*/res/ | sort)
DEVICE_OVERLAYS_FILES := $(shell find device/generic/goldfish/phone/overlay/frameworks/base/packages/overlays/*/AndroidOverlay/res/ | sort)
$(LAYOUTLIB_RES)/layoutlib-res.zip: $(SOONG_ZIP) $(HOST_OUT_EXECUTABLES)/aapt2 $(LAYOUTLIB_RES_FILES) $(EMULATED_OVERLAYS_FILES) $(DEVICE_OVERLAYS_FILES)
	rm -rf $@
	echo $(LAYOUTLIB_RES_FILES) > $(LAYOUTLIB_RES)/filelist_res.txt
	$(SOONG_ZIP) -C frameworks/base/core/res -l $(LAYOUTLIB_RES)/filelist_res.txt -o $(LAYOUTLIB_RES)/temp_res.zip
	echo $(EMULATED_OVERLAYS_FILES) > $(LAYOUTLIB_RES)/filelist_emulated_overlays.txt
	$(SOONG_ZIP) -C frameworks/base/packages -l $(LAYOUTLIB_RES)/filelist_emulated_overlays.txt -o $(LAYOUTLIB_RES)/temp_emulated_overlays.zip
	echo $(DEVICE_OVERLAYS_FILES) > $(LAYOUTLIB_RES)/filelist_device_overlays.txt
	$(SOONG_ZIP) -C device/generic/goldfish/phone/overlay/frameworks/base/packages -l $(LAYOUTLIB_RES)/filelist_device_overlays.txt -o $(LAYOUTLIB_RES)/temp_device_overlays.zip
	rm -rf $(LAYOUTLIB_RES)/data && unzip -q -d $(LAYOUTLIB_RES)/data $(LAYOUTLIB_RES)/temp_res.zip
	unzip -q -d $(LAYOUTLIB_RES)/data $(LAYOUTLIB_RES)/temp_emulated_overlays.zip
	unzip -q -d $(LAYOUTLIB_RES)/data $(LAYOUTLIB_RES)/temp_device_overlays.zip
	rm -rf $(LAYOUTLIB_RES)/compiled && mkdir $(LAYOUTLIB_RES)/compiled && $(HOST_OUT_EXECUTABLES)/aapt2 compile $(LAYOUTLIB_RES)/data/res/**/*.9.png -o $(LAYOUTLIB_RES)/compiled
	printf '<?xml version="1.0" encoding="utf-8"?>\n<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.google.android.layoutlib" />' > $(LAYOUTLIB_RES)/AndroidManifest.xml
	$(HOST_OUT_EXECUTABLES)/aapt2 link -R $(LAYOUTLIB_RES)/compiled/* -o $(LAYOUTLIB_RES)/compiled.apk --manifest $(LAYOUTLIB_RES)/AndroidManifest.xml
	rm -rf $(LAYOUTLIB_RES)/compiled_apk && unzip -q -d $(LAYOUTLIB_RES)/compiled_apk $(LAYOUTLIB_RES)/compiled.apk
	for f in $(LAYOUTLIB_RES)/compiled_apk/res/*; do mv "$$f" "$${f/-v4/}";done
	for f in $(LAYOUTLIB_RES)/compiled_apk/res/**/*.9.png; do mv "$$f" "$${f/.9.png/.compiled.9.png}";done
	cp -r $(LAYOUTLIB_RES)/compiled_apk/res $(LAYOUTLIB_RES)/data
	$(SOONG_ZIP) -C $(LAYOUTLIB_RES)/data -D $(LAYOUTLIB_RES)/data/ -o $@

$(call dist-for-goals,layoutlib,$(LAYOUTLIB_RES)/layoutlib-res.zip:layoutlib_native/res.zip)

# SBOM of layoutlib artifacts
LAYOUTLIB_SBOM := $(call intermediates-dir-for,PACKAGING,layoutlib-sbom,HOST)
_layoutlib_font_config_files := $(sort $(wildcard frameworks/base/data/fonts/*.xml))
_layoutlib_fonts_files := $(filter $(TARGET_OUT)/fonts/%.ttf $(TARGET_OUT)/fonts/%.ttc $(TARGET_OUT)/fonts/%.otf, $(INTERNAL_SYSTEMIMAGE_FILES))
_layoutlib_keyboard_files := $(sort $(wildcard frameworks/base/data/keyboards/*.kcm))

# Find out files disted with layoutlib in Soong.
### Filter out static libraries for Windows and files already handled in make.
_layoutlib_filter_out_disted := $(addprefix layoutlib_native/,fonts/% keyboards/% build.prop res.zip windows/%.a)
_layoutlib_files_disted_by_soong := \
  $(strip \
    $(foreach p,$(_all_dist_src_dst_pairs), \
      $(if $(filter-out $(_layoutlib_filter_out_disted),$(filter layoutlib_native/% layoutlib.jar,$(call word-colon,2,$p))),$p)))

$(LAYOUTLIB_SBOM)/sbom-metadata.csv:
	rm -rf $@
	echo installed_file,module_path,soong_module_type,is_prebuilt_make_module,product_copy_files,kernel_module_copy_files,is_platform_generated,build_output_path,static_libraries,whole_static_libraries,is_static_lib >> $@
	echo build.prop,,,,,,Y,$(LAYOUTLIB_BUILD_PROP)/layoutlib-build.prop,,, >> $@

	$(foreach f,$(_layoutlib_font_config_files),\
	  echo data/fonts/$(notdir $f),frameworks/base/data/fonts,prebuilt_etc,,,,,$f,,, >> $@; \
	)

	$(foreach f,$(_layoutlib_fonts_files), \
	  $(eval _module_name := $(ALL_INSTALLED_FILES.$f)) \
	  $(eval _module_path := $(strip $(sort $(ALL_MODULES.$(_module_name).PATH)))) \
	  $(eval _soong_module_type := $(strip $(sort $(ALL_MODULES.$(_module_name).SOONG_MODULE_TYPE)))) \
	  echo data/fonts/$(notdir $f),$(_module_path),$(_soong_module_type),,,,,$f,,, >> $@; \
	)

	$(foreach f,$(_layoutlib_keyboard_files), \
	  echo data/keyboards/$(notdir $f),frameworks/base/data/keyboards,prebuilt_etc,,,,,$f,,, >> $@; \
	)

	$(foreach f,$(_layoutlib_files_disted_by_soong), \
	  $(eval _prebuilt_module_file := $(call word-colon,1,$f)) \
	  $(eval _dist_file := $(call word-colon,2,$f)) \
	  $(eval _dist_file := $(patsubst data/windows/%,data/win/lib64/%,$(patsubst layoutlib_native/%,data/%,$(_dist_file)))) \
	  $(eval _dist_file := $(subst layoutlib.jar,data/layoutlib.jar,$(_dist_file))) \
	  $(eval _module_name := $(strip $(foreach m,$(ALL_MODULES),$(if $(filter $(_prebuilt_module_file),$(ALL_MODULES.$m.CHECKED)),$m)))) \
	  $(eval _module_path := $(strip $(sort $(ALL_MODULES.$(_module_name).PATH)))) \
	  $(eval _soong_module_type := $(strip $(sort $(ALL_MODULES.$(_module_name).SOONG_MODULE_TYPE)))) \
	  echo $(patsubst layoutlib_native/%,%,$(_dist_file)),$(_module_path),$(_soong_module_type),,,,,$(_prebuilt_module_file),,, >> $@; \
	)

	$(foreach f,$(LAYOUTLIB_RES_FILES), \
	  $(eval _path := $(subst frameworks/base/core/res,data,$f)) \
	  echo $(_path),,,,,,Y,$f,,, >> $@; \
	)

	$(foreach f,$(EMULATED_OVERLAYS_FILES), \
	  $(eval _path := $(subst frameworks/base/packages,data,$f)) \
	  echo $(_path),,,,,,Y,$f,,, >> $@; \
	)

	$(foreach f,$(DEVICE_OVERLAYS_FILES), \
	  $(eval _path := $(subst device/generic/goldfish/phone/overlay/frameworks/base/packages,data,$f)) \
	  echo $(_path),,,,,,Y,$f,,, >> $@; \
	)

.PHONY: layoutlib-sbom
layoutlib-sbom: $(LAYOUTLIB_SBOM)/layoutlib.spdx.json
$(LAYOUTLIB_SBOM)/layoutlib.spdx.json: $(PRODUCT_OUT)/always_dirty_file.txt $(GEN_SBOM) $(LAYOUTLIB_SBOM)/sbom-metadata.csv $(_layoutlib_font_config_files) $(_layoutlib_fonts_files) $(LAYOUTLIB_BUILD_PROP)/layoutlib-build.prop $(_layoutlib_keyboard_files) $(LAYOUTLIB_RES_FILES) $(EMULATED_OVERLAYS_FILES) $(DEVICE_OVERLAYS_FILES)
	rm -rf $@
	$(GEN_SBOM) --output_file $@ --metadata $(LAYOUTLIB_SBOM)/sbom-metadata.csv --build_version $(BUILD_FINGERPRINT_FROM_FILE) --product_mfr "$(PRODUCT_MANUFACTURER)" --module_name "layoutlib" --json

$(call dist-for-goals,layoutlib,$(LAYOUTLIB_SBOM)/layoutlib.spdx.json:layoutlib_native/sbom/layoutlib.spdx.json)

# Generate SBOM of framework_res.jar that is created in release_layoutlib.sh.
# The generated SBOM contains placeholders for release_layoutlib.sh to substitute, and the placeholders include:
# document name, document namespace, document creation info, organization and SHA1 value of framework_res.jar.
GEN_SBOM_FRAMEWORK_RES := $(HOST_OUT_EXECUTABLES)/generate-sbom-framework_res
.PHONY: layoutlib-framework_res-sbom
layoutlib-framework_res-sbom: $(LAYOUTLIB_SBOM)/framework_res.jar.spdx.json
$(LAYOUTLIB_SBOM)/framework_res.jar.spdx.json: $(LAYOUTLIB_SBOM)/layoutlib.spdx.json $(GEN_SBOM_FRAMEWORK_RES)
	rm -rf $@
	$(GEN_SBOM_FRAMEWORK_RES) --output_file $(LAYOUTLIB_SBOM)/framework_res.jar.spdx.json --layoutlib_sbom $(LAYOUTLIB_SBOM)/layoutlib.spdx.json

$(call dist-for-goals,layoutlib,$(LAYOUTLIB_SBOM)/framework_res.jar.spdx.json:layoutlib_native/sbom/framework_res.jar.spdx.json)