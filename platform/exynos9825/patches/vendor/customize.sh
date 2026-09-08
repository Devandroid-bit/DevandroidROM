LOG_STEP_IN "- Updating Vendor HALs"

# Keep SNAP HALs for the Galaxy S22-based port.
# Remove the legacy SysInput stack and incompatible vendor HALs.

BLOBS_LIST="
bin/hw/android.hardware.health@2.1-service-samsung
bin/hw/vendor.samsung.hardware.sysinput@1.2-service
bin/hw/vendor.samsung.hardware.vibrator@2.2-service
etc/audio_policy_configuration_sec.xml
etc/init/android.hardware.health@2.1-service-samsung.rc
etc/init/vendor.samsung.hardware.sysinput@1.2-service.rc
etc/init/vendor.samsung.hardware.vibrator@2.2-service.rc
etc/vintf/manifest/android.hardware.health@2.1-samsung.xml
lib/android.hardware.health@2.1.so
lib/hw/android.hardware.graphics.mapper@2.0-impl.so
lib64/android.hardware.health@2.1.so
lib64/android.hardware.vibrator@1.0.so
lib64/android.hardware.vibrator@1.1.so
lib64/android.hardware.vibrator@1.2.so
lib64/android.hardware.vibrator@1.3.so
lib64/hw/android.hardware.graphics.mapper@2.0-impl.so
lib64/vendor.samsung.hardware.vibrator@2.0.so
lib64/vendor.samsung.hardware.vibrator@2.1.so
lib64/vendor.samsung.hardware.vibrator@2.2.so
"

for blob in $BLOBS_LIST
do
    DELETE_FROM_WORK_DIR "vendor" "$blob"
done

LOG_STEP_OUT


LOG_STEP_IN "- Removing RenderScript"

BLOBS_LIST="
bin/bcc_mali
lib/libmalicore.bc
lib/libclcore.bc
lib/libclcore_neon.bc
lib/libRSDriverArm.so
lib64/libLLVM_android_mali.so
lib64/libbcc_mali.so
lib64/libbccArm.so
lib64/libclcore.bc
lib64/libmalicore.bc
lib64/libRSDriverArm.so
"

for blob in $BLOBS_LIST
do
    DELETE_FROM_WORK_DIR "vendor" "$blob"
done

LOG_STEP_OUT

LOG "- Fixing SNAP AIDL SELinux rule"

sed -i "s/(allow snap_hidl hal_snap_service (service_manager (find)))/(allow snap_hidl hal_snap_service (service_manager (add find)))/" \
    "$WORK_DIR/system/system/etc/selinux/plat_sepolicy.cil"

LOG_STEP_IN "- Removing RenderScript"

BLOBS_LIST="
bin/bcc_mali
lib/libmalicore.bc
lib/libclcore.bc
lib/libclcore_neon.bc
lib/libRSDriverArm.so
lib64/libLLVM_android_mali.so
lib64/libbcc_mali.so
lib64/libbccArm.so
lib64/libclcore.bc
lib64/libmalicore.bc
lib64/libRSDriverArm.so
"

for blob in $BLOBS_LIST; do
    DELETE_FROM_WORK_DIR "vendor" "$blob"
done

LOG_STEP_OUT
LOG "- Fixing JSQZ node permission"
echo "/dev/jsqz                 0660   mediacodec     camera" >> $WORK_DIR/vendor/ueventd.rc

LOG_STEP_IN "- Adding S21 (p3sxxx) Light HAL and some exynos9825 fixes"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "bin/hw/vendor.samsung.hardware.light-service"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "bin/hw/wpa_supplicant"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "bin/hw/android.hardware.media.omx@1.0-service"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "bin/hw/vendor.samsung.hardware.thermal@1.0-service"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "bin/hw/android.hardware.audio.service"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "lib64/android.hardware.light-V1-ndk_platform.so"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "lib64/vendor.samsung.hardware.light-V1-ndk_platform.so"
LOG_STEP_OUT
