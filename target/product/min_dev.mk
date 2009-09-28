
PRODUCT_POLICY := android.policy_phone
PRODUCT_PROPERTY_OVERRIDES := \
    ro.config.notification_sound=OnTheHunt.ogg \
    ro.config.alarm_alert=Alarm_Classic.ogg
PRODUCT_BRAND := generic
PRODUCT_NAME := min_dev
PRODUCT_DEVICE := generic

PRODUCT_PACKAGES := \
    DownloadProvider \
    GoogleSearch \
    MediaProvider \
    SettingsProvider \
    PackageInstaller \
    Bugreport \
    Launcher \
    Settings \
    sqlite3

