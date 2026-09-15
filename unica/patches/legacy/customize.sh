# shellcheck disable=SC2034
SKIPUNZIP=1

PATCHED=false

LOG "- Applying Framework & HAL Translation Patches for One UI 8..."

# 1. Biometrics HAL Downgrade (Face V3.0 -> V2.0)
if [ ! -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.biometrics.face@3.0-service" ]; then
    PATCHED=true
    LOG "- Downgrading ISehBiometricsFace from V3.0 to V2.0 in services.jar"
    SMALI_PATCH "system" "system/framework/services.jar" \
        "smali/com/android/server/biometrics/sensors/face/hidl/HidlToAidlCallbackConverter.smali" "replaceall" \
        "V3_0" \
        "V2_0" \
        > /dev/null
    SMALI_PATCH "system" "system/framework/services.jar" \
        "smali/com/android/server/biometrics/sensors/face/hidl/TestHal.smali" "replaceall" \
        "V3_0" \
        "V2_0" \
        > /dev/null
    SMALI_PATCH "system" "system/framework/services.jar" \
        "smali/com/android/server/biometrics/sensors/face/aidl/SemFaceServiceExImpl\$\$ExternalSyntheticLambda6.smali" "remove"
    EVAL "rm -f \"$APKTOOL_DIR/system/framework/services.jar/smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace.smali\""
    EVAL "rm -f \"$APKTOOL_DIR/system/framework/services.jar/smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace\\\$Proxy.smali\""
fi

# 2. Legacy OMX Video Codec Fallback (libstagefright.so)
if xxd -p -c 0 "$WORK_DIR/system/system/lib64/libstagefright.so" | grep -q "70690594205100347a9a40f9"; then
    PATCHED=true
    LOG "- Hex-patching libstagefright.so for legacy Exynos OMX"
    HEX_PATCH "$WORK_DIR/system/system/lib64/libstagefright.so" \
        "70690594205100347a9a40f9" "706905941f2003d57a9a40f9"
elif xxd -p -c 0 "$WORK_DIR/system/system/lib64/libstagefright.so" | grep -q "864d0594604d00347a9a40f9"; then
    PATCHED=true
    LOG "- Hex-patching libstagefright.so for legacy Exynos OMX"
    HEX_PATCH "$WORK_DIR/system/system/lib64/libstagefright.so" \
        "864d0594604d00347a9a40f9" "864d05941f2003d57a9a40f9"
fi

# 3. Network BPF Bypass (netd)
if [ -f "$WORK_DIR/system/system/bin/netd" ]; then
    if xxd -p -c 0 "$WORK_DIR/system/system/bin/netd" | grep -q "1f01096be0010054"; then
        PATCHED=true
        LOG "- Patching netd to bypass strict eBPF checks"
        HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096be0010054" "1f01096b1f2003d5"
    fi
fi

# 4. SurfaceFlinger & Hardware Props
if [ -f "$WORK_DIR/vendor/build.prop" ]; then
    PATCHED=true
    LOG "- Injecting display and NFC translation props"
    EVAL "sed -i \"/ro.surface_flinger.use_content_detection_for_refresh_rate/d\" \"$WORK_DIR/vendor/build.prop\""
    EVAL "sed -i \"\$a debug.sf.use_content_detection_for_refresh_rate=0\" \"$WORK_DIR/vendor/build.prop\""
    EVAL "sed -i \"\$a ro.vendor.nfc.support.legacy=true\" \"$WORK_DIR/vendor/build.prop\""
fi

# 5. Camera NPU Model Swaps
if grep -q "default_lowtier" "$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json" &&
        [ -f "$WORK_DIR/system/system/cameradata/portrait_data/SRIB_HumanInsSeg_FP16_V008.snf" ]; then
    PATCHED=true
    LOG "- Swapping heavy NPU models for BanetLite"
    DELETE_FROM_WORK_DIR "system" "system/cameradata/portrait_data/SRIB_HumanInsSeg_FP16_V008.snf"
    ADD_TO_WORK_DIR "a17xxx" "system" \
        "system/cameradata/portrait_data/SRIB_BanetLite_FP16_V400.snf" 0 0 644 "u:object_r:system_file:s0"
    EVAL "sed -i \"0,/HumanInsSeg_FP16_V008/s//BanetLite_FP16_V400/\" \"$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json\""
    EVAL "sed -i \"0,/008/s//400/\" \"$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json\""
fi

if ! $PATCHED; then
    LOG "\033[0;33m! Nothing to do\033[0m"
fi

unset PATCHED
