PRODUCT_PROPERTY_OVERRIDES :=

PRODUCT_PACKAGES := \
	AlarmClock \
	Camera \
	Calculator \
	Development \
	DrmProvider \
	Email \
	Fallback \
	GPSEnable \
	Launcher \
	Music \
	Mms \
	Settings \
	SdkSetup \
	CustomLocale \
	gpstest \
	sqlite3 \
	LatinIME \
	PinyinIME \
	ApiDemos \
	SoftKeyboard

PRODUCT_COPY_FILES := \
	development/data/etc/vold.conf:system/etc/vold.conf

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_NAME := sdk
PRODUCT_DEVICE := generic
PRODUCT_LOCALES := \
	en_US \
	en_GB \
	en_CA \
	en_AU \
	en_NZ \
	en_SG \
	ja_JP \
	fr_FR \
	fr_BE \
	fr_CA \
	fr_CH \
	it_IT \
	it_CH \
	es_ES \
	de_DE \
	de_AT \
	de_CH \
	de_LI \
	nl_NL \
	nl_BE \
	cs_CZ \
	pl_PL \
	zh_CN \
	zh_TW \
	ru_RU \
	ko_KR

