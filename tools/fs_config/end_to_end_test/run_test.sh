cd $ANDROID_BUILD_TOP/build/make/tools/fs_config/end_to_end_test

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition system \
  --all-partitions vendor,product \
  --files \
  --out_file result_system_fs_config_files \
  ./config.fs

diff system_fs_config_files result_system_fs_config_files 1>/dev/null && echo 'Success system_fs_config_files' ||
  echo 'Fail: Mismatch between system_fs_config_files and result_system_fs_config_files'

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition system \
  --all-partitions vendor,product \
  --dirs \
  --out_file result_system_fs_config_dirs \
  ./config.fs

diff system_fs_config_dirs result_system_fs_config_dirs 1>/dev/null && echo 'Success system_fs_config_dirs' ||
  echo 'Fail: Mismatch between system_fs_config_dirs and result_system_fs_config_dirs'

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition vendor \
  --files \
  --out_file result_vendor_fs_config_files \
  ./config.fs

diff vendor_fs_config_files result_vendor_fs_config_files 1>/dev/null && echo 'Success vendor_fs_config_files' ||
  echo 'Fail: Mismatch between vendor_fs_config_files and result_vendor_fs_config_files'

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition vendor \
  --dirs \
  --out_file result_vendor_fs_config_dirs \
  ./config.fs

diff vendor_fs_config_dirs result_vendor_fs_config_dirs 1>/dev/null && echo 'Success vendor_fs_config_dirs' ||
  echo 'Fail: Mismatch between vendor_fs_config_dirs and result_vendor_fs_config_dirs'

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition product \
  --files \
  --out_file result_product_fs_config_files \
  ./config.fs

diff product_fs_config_files result_product_fs_config_files 1>/dev/null && echo 'Success product_fs_config_files' ||
  echo 'Fail: Mismatch between product_fs_config_files and result_product_fs_config_files'

$ANDROID_BUILD_TOP/build/make/tools/fs_config/fs_config_generator.py fsconfig \
  --aid-header $ANDROID_BUILD_TOP/system/core/include/private/android_filesystem_config.h \
  --capability-header $ANDROID_BUILD_TOP/bionic/libc/kernel/uapi/linux/capability.h \
  --partition product \
  --dirs \
  --out_file result_product_fs_config_dirs \
  ./config.fs

diff product_fs_config_dirs result_product_fs_config_dirs 1>/dev/null && echo 'Success product_fs_config_dirs' ||
  echo 'Fail: Mismatch between product_fs_config_dirs and result_product_fs_config_dirs'

rm result_system_fs_config_files
rm result_system_fs_config_dirs
rm result_vendor_fs_config_files
rm result_vendor_fs_config_dirs
rm result_product_fs_config_files
rm result_product_fs_config_dirs
