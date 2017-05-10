###############################################################################
# Fonts shipped with the SDK need to be renamed for Java to handle them
# properly. Hence, a special script is used to rename the fonts. We bundle all
# the fonts that are shipped on a newer non-space-constrained device. However,
# OpenType fonts used on these devices are not supported by Java. Their
# replacements are added separately.
###############################################################################


# The script that renames the font.
sdk_font_rename_script := frameworks/layoutlib/rename_font/build_font_single.py

# Location of the fonttools library that the above script depends on.
fonttools_lib := external/fonttools/Lib

# A temporary location to store the renamed fonts. atree picks all files in
# this directory and bundles it with the SDK.
SDK_FONT_TEMP := $(call intermediates-dir-for,PACKAGING,sdk-fonts,HOST,COMMON)

# The font configuration files - system_fonts.xml, fallback_fonts.xml etc.
sdk_font_config := $(sort $(wildcard frameworks/base/data/fonts/*.xml))
sdk_font_config :=  $(addprefix $(SDK_FONT_TEMP)/, $(notdir $(sdk_font_config)))

$(sdk_font_config): $(SDK_FONT_TEMP)/%.xml: \
			frameworks/base/data/fonts/%.xml
	$(hide) mkdir -p $(dir $@)
	$(hide) cp -vf $< $@

# List of fonts on the device that we want to ship. This is all .ttf fonts.
sdk_fonts_device := $(filter $(TARGET_OUT)/fonts/%.ttf, $(INTERNAL_SYSTEMIMAGE_FILES))
sdk_fonts_device := $(addprefix $(SDK_FONT_TEMP)/, $(notdir $(sdk_fonts_device)))

# Macro to rename the font.
sdk_rename_font = PYTHONPATH=$$PYTHONPATH:$(fonttools_lib) $(sdk_font_rename_script) \
	    $1 $2

# TODO: If the font file is a symlink, reuse the font renamed from the symlink
# target.
$(sdk_fonts_device): $(SDK_FONT_TEMP)/%.ttf: $(TARGET_OUT)/fonts/%.ttf \
			$(sdk_font_rename_script)
	$(hide) mkdir -p $(dir $@)
	$(hide) $(call sdk_rename_font,$<,$@)

# List of all dependencies - all fonts and configuration files.
SDK_FONT_DEPS := $(sdk_fonts_device) $(sdk_font_config)

# Define a macro to create rule for addititional fonts that we want to include
# in the SDK.
# $1 Output font name
# $2 Source font path
define sdk-extra-font-rule
fontfullname := $$(SDK_FONT_TEMP)/$1
ifeq ($$(filter $$(fontfullname),$$(sdk_fonts_device)),)
SDK_FONT_DEPS += $$(fontfullname)
$$(fontfullname): $2 $$(sdk_font_rename_script)
	$$(hide) mkdir -p $$(dir $$@)
	$$(hide) $$(call sdk_rename_font,$$<,$$@)
endif
fontfullname :=
endef

# These extra fonts are used as a replacement for OpenType fonts.
$(eval $(call sdk-extra-font-rule,NanumGothic.ttf,external/naver-fonts/NanumGothic.ttf))
$(eval $(call sdk-extra-font-rule,DroidSansFallback.ttf,frameworks/base/data/fonts/DroidSansFallbackFull.ttf))

sdk-extra-font-rule :=
