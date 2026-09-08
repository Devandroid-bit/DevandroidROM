MATCH_TARGET_FEATURES()
{
    local SOURCE_FEATURES
    local TARGET_FEATURES

    SOURCE_FEATURES="$(find "$WORK_DIR/system/system/etc/permissions" -name "com.sec.feature*" -printf "%f\n")"
    SOURCE_FEATURES="$(sort <<< "$SOURCE_FEATURES")"
    TARGET_FEATURES="$(find "$TARGET_FIRMWARE_PATH/system/system/etc/permissions" -name "com.sec.feature*" -printf "%f\n")"
    TARGET_FEATURES="$(sort <<< "$TARGET_FEATURES")"

    for f in $SOURCE_FEATURES; do
        if ! grep -q "$f" <<< "$TARGET_FEATURES"; then
            DELETE_FROM_WORK_DIR "system" "system/etc/permissions/$f"
        fi
    done
    for f in $TARGET_FEATURES; do
        if ! grep -q "$f" <<< "$SOURCE_FEATURES"; then
            ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/permissions/$f" 0 0 644 "u:object_r:system_file:s0"
        fi
    done
}

SOURCE_FIRMWARE_PATH="$FW_DIR/$(echo -n "$SOURCE_FIRMWARE" | sed 's./._.g' | rev | cut -d "_" -f2- | rev)"
TARGET_FIRMWARE_PATH="$FW_DIR/$(echo -n "$TARGET_FIRMWARE" | sed 's./._.g' | rev | cut -d "_" -f2- | rev)"

LOG_STEP_IN "- Replacing saiv blobs"
DELETE_FROM_WORK_DIR "system" "system/saiv"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE_PATH" "system" "system/saiv" 0 0 755 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/saiv/face"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "system" "system/saiv/face" 0 0 755 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/saiv/textrecognition"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "system" "system/saiv/textrecognition" 0 0 755 "u:object_r:system_file:s0"
LOG_STEP_OUT

LOG_STEP_IN "- Replacing cameradata blobs"
DELETE_FROM_WORK_DIR "system" "system/cameradata"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE_PATH" "system" "system/cameradata" 0 0 755 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/cameradata/preloadfilters"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "system" "system/cameradata/preloadfilters" 0 0 755 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/cameradata/myfilter"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "system" "system/cameradata/myfilter" 0 0 755 "u:object_r:system_file:s0"
LOG_STEP_OUT

# TODO add APE/DSD extractor libs if required
if [ -f "$WORK_DIR/system/system/lib64/extractors/libsapeextractor.so" ] && \
        [ ! "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_APE_FORMAT")" ]; then
    DELETE_FROM_WORK_DIR "system" "system/lib64/extractors/libsapeextractor.so"
fi
if [ -f "$WORK_DIR/system/system/lib64/extractors/libsdffextractor.so" ] && \
        [ ! "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_DSD_FORMAT")" ]; then
    DELETE_FROM_WORK_DIR "system" "system/lib64/extractors/libsdffextractor.so"
fi
if [ -f "$WORK_DIR/system/system/lib64/extractors/libsdsfextractor.so" ] && \
        [ ! "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_DSD_FORMAT")" ]; then
    DELETE_FROM_WORK_DIR "system" "system/lib64/extractors/libsdsfextractor.so"
fi

if [ -f "$TARGET_FIRMWARE_PATH/system/system/priv-app/SohService/SohService.apk" ]; then
    DECODE_APK "system" "system/priv-app/SohService/SohService.apk"

    LOG "- Adding target BSOH blobs"
    EVAL "rm -r \"$APKTOOL_DIR/system/priv-app/SohService/SohService.apk/assets\""
    EVAL "unzip -q \"$TARGET_FIRMWARE_PATH/system/system/priv-app/SohService/SohService.apk\" \"assets/*\" -d \"$APKTOOL_DIR/system/priv-app/SohService/SohService.apk\""
else
    if [ -f "$WORK_DIR/system/system/priv-app/SohService/SohService.apk" ]; then
        DELETE_FROM_WORK_DIR "system" "system/priv-app/SohService"
    fi
fi

if [ -f "$TARGET_FIRMWARE_PATH/system/system/usr/share/alsa/alsa.conf" ]; then
    LOG_STEP_IN "- Replacing alsa.conf"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE_PATH" "system" "system/usr/share/alsa/alsa.conf" 0 0 644 "u:object_r:system_file:s0"
    LOG_STEP_OUT
fi

LOG_STEP_IN "- Replacing gamebooster props"
SET_PROP "product" "ro.gfx.driver.0" "$(GET_PROP "$WORK_DIR/vendor/build.prop" "ro.gfx.driver.0")"
SET_PROP "product" "ro.gfx.driver.1" "$(GET_PROP "$WORK_DIR/vendor/build.prop" "ro.gfx.driver.1")"
LOG_STEP_OUT
