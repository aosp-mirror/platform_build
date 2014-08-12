###############################################################################
# Fonts shipped with the SDK need to be renamed for Java to handle them
# properly. Hence, a special script is used to rename the fonts. We bundle all
# the fonts that are shipped on a newer non-space-constrained device. However,
# OpenType fonts used on these devices are not supported by Java. Their
# replacements are added separately.
###############################################################################


# The script that renames the font.
sdk_font_rename_script := frameworks/base/tools/layoutlib/rename_font/build_font_single.py

# Location of the fonttools library that the above script depends on.
fonttools_lib := external/fonttools/Lib

# A temporary location to store the renamed fonts. atree picks all files in
# this directory and bundles it with the SDK.
SDK_FONT_TEMP := $(call intermediates-dir-for,PACKAGING,sdk-fonts,HOST,COMMON)

# The font configuration files - system_fonts.xml, fallback_fonts.xml etc.
sdk_font_config := $(wildcard frameworks/base/data/fonts/*.xml)
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

# Extra fonts that are not part of the device build. These are used as a
# replacement for the OpenType fonts.
sdk_fonts_extra := NanumGothic.ttf DroidSansFallback.ttf
sdk_fonts_extra := $(addprefix $(SDK_FONT_TEMP)/, $(sdk_fonts_extra))

$(SDK_FONT_TEMP)/NanumGothic.ttf: external/naver-fonts/NanumGothic.ttf \
			$(sdk_font_rename_script)
	$(hide) mkdir -p $(dir $@)
	$(hide) $(call sdk_rename_font,$<,$@)

$(SDK_FONT_TEMP)/DroidSansFallback.ttf: frameworks/base/data/fonts/DroidSansFallbackFull.ttf \
			$(sdk_font_rename_script)
	$(hide) mkdir -p $(dir $@)
	$(hide) $(call sdk_rename_font,$<,$@)

# List of all dependencies - all fonts and configuration files.
SDK_FONT_DEPS := $(sdk_fonts_device) $(sdk_fonts_extra) $(sdk_font_config)

