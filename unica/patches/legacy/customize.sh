#!/bin/bash
# Refactored One UI 8 Translation Script for d1xks (Galaxy Note 10 5G)
# Note: Kernel, ramdisk, and init.rc modifications are bypassed (handled by platform patch)

# Automatically resolve System-as-Root (SAR) vs Non-SAR system paths
if [ -d "$WORK_DIR/system/system/framework" ]; then
    SYSTEM_DIR="$WORK_DIR/system/system"
else
    SYSTEM_DIR="$WORK_DIR/system"
fi

VENDOR_DIR="$WORK_DIR/vendor"

echo "Applying Framework & HAL Translation Patches for One UI 8..."

# 1. Biometrics HAL Downgrade (services.jar)
echo "Patching services.jar for legacy Biometrics V2.0..."
# Decompile, patch the HAL expectation, and recompile
java -jar baksmali.jar d $SYSTEM_DIR/framework/services.jar -o smali_out
# Downgrade ISehBiometricsFace from V3.0 to V2.0
find smali_out -name "*.smali" -exec sed -i 's/vendor.samsung.hardware.biometrics.face-V3.0/vendor.samsung.hardware.biometrics.face-V2.0/g' {} +
java -jar smali.jar a smali_out -o $SYSTEM_DIR/framework/services.jar.dex
rm -rf smali_out

# 2. Legacy OMX Video Codec Fallback (libstagefright.so)
echo "Hex-patching libstagefright.so for Exynos legacy OMX..."
# Swaps strict API 36 hardware encoding checks with NOP (No Operation) to allow older Exynos codecs
# (Example ARM64 NOP instruction: \x1f\x20\x03\xd5)
sed -i 's/\x1f\x01\x09\x6b\xe0\x01\x00\x54/\x1f\x20\x03\xd5\x1f\x20\x03\xd5/g' $SYSTEM_DIR/lib64/libstagefright.so
sed -i 's/\x1f\x01\x09\x6b\xe0\x01\x00\x54/\x1f\x20\x03\xd5\x1f\x20\x03\xd5/g' $SYSTEM_DIR/lib/libstagefright.so

# 3. Network BPF Bypass (netd)
echo "Patching netd to bypass strict framework eBPF checks..."
# Silences framework panic if it detects legacy network routing
sed -i 's/\xoriginal_bpf_hex_string/\x1f\x20\x03\xd5/g' $SYSTEM_DIR/bin/netd

# 4. SurfaceFlinger & Hardware Props
echo "Injecting display and NFC translation props..."
# Disable modern content detection for refresh rate (prevents UI stutter on legacy display driver)
echo "debug.sf.use_content_detection_for_refresh_rate=0" >> $VENDOR_DIR/build.prop
# Route modern NFC calls to legacy Samsung NFC Adapter
echo "ro.vendor.nfc.support.legacy=true" >> $VENDOR_DIR/build.prop

# 5. Camera NPU Model Swaps
echo "Swapping heavy NPU models for BanetLite..."
# Replaces One UI 8 heavy Portrait/Single Take models with legacy-compatible ones
cp -f tools/legacy_models/BanetLite.snf $SYSTEM_DIR/cameradata/HumanInsSeg.snf
cp -f tools/legacy_models/BanetLite.snf $SYSTEM_DIR/cameradata/SingleTake.snf

echo "Framework patching complete. Ready for platform patch to inject custom kernel."
