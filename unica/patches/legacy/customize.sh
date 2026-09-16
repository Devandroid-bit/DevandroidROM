# shellcheck disable=SC2034
SKIPUNZIP=1

PATCHED=false

# Runs EVAL in a subshell so an internal `exit` only kills the subshell,
# logs the failing command instead of dying, matching the SAIV fix pattern.
# Only applied to the section that failed and the section that never got a
# chance to run -- the two hex patches above already proved working in the
# last build and are left untouched.
SAFE_EVAL() {
    ( EVAL "$1" ) || LOG "!! EVAL failed, continuing anyway: $1"
}

LOG "- Applying Framework & HAL Translation Patches for One UI 8..."

# 1. Legacy OMX Video Codec Fallback (libstagefright.so)
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

# 2. Network BPF Bypass (netd)
if [ -f "$WORK_DIR/system/system/bin/netd" ]; then
    if xxd -p -c 0 "$WORK_DIR/system/system/bin/netd" | grep -q "1f01096be0010054"; then
        PATCHED=true
        LOG "- Patching netd to bypass strict eBPF checks"
        HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096be0010054" "1f01096b1f2003d5"
    fi
fi

# 3. SurfaceFlinger & Hardware Props
# FIXED: the previous version used `sed -i "$a ..."` (append after last
# line) inside EVAL. EVAL evaluates its argument a second time, and by then
# the backslash protecting "$a" is gone, so it gets read as an empty shell
# variable instead of sed's last-line syntax -- sed then chokes on the
# malformed leftover script. Appending directly avoids the sed escaping
# entirely.
if [ -f "$WORK_DIR/vendor/build.prop" ]; then
    PATCHED=true
    LOG "- Injecting display and NFC translation props"
    SAFE_EVAL "sed -i \"/ro.surface_flinger.use_content_detection_for_refresh_rate/d\" \"$WORK_DIR/vendor/build.prop\""
    SAFE_EVAL "echo \"debug.sf.use_content_detection_for_refresh_rate=0\" >> \"$WORK_DIR/vendor/build.prop\""
    SAFE_EVAL "echo \"ro.vendor.nfc.support.legacy=true\" >> \"$WORK_DIR/vendor/build.prop\""
fi

# 4. Camera NPU Model Swaps
# Never reached in the failed build -- wrapped defensively since it's
# untested, not because it's confirmed broken.
if grep -q "default_lowtier" "$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json" && \
        [ -f "$WORK_DIR/system/system/cameradata/portrait_data/SRIB_HumanInsSeg_FP16_V008.snf" ]; then
    PATCHED=true
    LOG "- Swapping heavy NPU models for BanetLite"
    DELETE_FROM_WORK_DIR "system" "system/cameradata/portrait_data/SRIB_HumanInsSeg_FP16_V008.snf"
    ADD_TO_WORK_DIR "a17xxx" "system" \
        "system/cameradata/portrait_data/SRIB_BanetLite_FP16_V400.snf" 0 0 644 "u:object_r:system_file:s0"
    SAFE_EVAL "sed -i \"0,/HumanInsSeg_FP16_V008/s//BanetLite_FP16_V400/\" \"$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json\""
    SAFE_EVAL "sed -i \"0,/008/s//400/\" \"$WORK_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json\""
fi

if ! $PATCHED; then
    LOG "\033[0;33m! Nothing to do\033[0m"
fi

unset PATCHED
unset -f SAFE_EVAL
