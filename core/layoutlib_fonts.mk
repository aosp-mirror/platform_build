# Fonts for layoutlib

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

# List of all dependencies - all fonts and configuration files.
FONT_FILES := $(fonts_device) $(font_config)

.PHONY: layoutlib layoutlib-tests
layoutlib layoutlib-tests: $(FONT_FILES)

$(call dist-for-goals, layoutlib, $(foreach m,$(FONT_FILES), $(m):layoutlib_native/fonts/$(notdir $(m))))

FONT_TEMP :=
font_config :=
fonts_device :=
FONT_FILES :=
