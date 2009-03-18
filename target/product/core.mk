PRODUCT_BRAND :=
PRODUCT_NAME :=
PRODUCT_DEVICE :=
PRODUCT_POLICY := android.policy_phone
PRODUCT_PROPERTY_OVERRIDES := \
    ro.config.notification_sound=F1_New_SMS.ogg

PRODUCT_PACKAGES := \
    framework-res \
    Browser \
    Contacts \
    Home \
    HTMLViewer \
    Phone \
    ContactsProvider \
    DownloadProvider \
    GoogleSearch \
    MediaProvider \
    SettingsProvider \
    TelephonyProvider \
    UserDictionaryProvider \
    PackageInstaller \
    Bugreport

#include basic ringtones
include frameworks/base/data/sounds/OriginalAudio.mk

