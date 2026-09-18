LOG_STEP_IN "- Adding SNAP AIDL stub service"

# Remove the original lazy-HAL declaration for the real (broken) snap
# service, so only our stub declares/provides this interface name.
DELETE_FROM_WORK_DIR "vendor" "etc/init/vendor.samsung.hardware.snap-lazy.rc"

# Install our stub binary and its always-on init service.
ADD_TO_WORK_DIR "$MODPATH/vendor" "vendor" "bin/snap_stub" 0 0 755 "u:object_r:hal_snap_stub_exec:s0"
ADD_TO_WORK_DIR "$MODPATH/vendor" "vendor" "etc/init/vendor.snap_stub.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"

# Append our SELinux type/domain declarations directly into the compiled
# vendor policy (same pattern already used for the existing snap_hidl fix).
# NOTE: this is the part most likely to need an iteration if you see
# avc: denied in logcat -- these macros assume standard AOSP CIL attribute
# names (domain, vendor_file_type, exec_type, file_type, service_manager_type).
cat >> "$WORK_DIR/vendor/etc/selinux/vendor_sepolicy.cil" << 'EOF'
(type hal_snap_stub)
(type hal_snap_stub_exec)
(type hal_snap_stub_service)
(roletype object_r hal_snap_stub_exec)
(roletype object_r hal_snap_stub_service)
(typeattributeset domain (hal_snap_stub))
(typeattributeset vendor_file_type (hal_snap_stub_exec))
(typeattributeset exec_type (hal_snap_stub_exec))
(typeattributeset file_type (hal_snap_stub_exec))
(typeattributeset service_manager_type (hal_snap_stub_service))

; allow init to exec our binary and transition into our own domain
(allow init hal_snap_stub_exec (file (getattr open read execute execute_no_trans map)))
(typetransition init hal_snap_stub_exec process hal_snap_stub)

; allow our domain to use binder and talk to servicemanager
(allow hal_snap_stub binder_device (chr_file (read write open ioctl map)))
(allow hal_snap_stub servicemanager (binder (call transfer)))
(allow hal_snap_stub self (binder (call transfer)))

; allow it to register (add) and be looked up (find) as a service
(allow hal_snap_stub hal_snap_stub_service (service_manager (add find)))
EOF

# Map the AIDL instance name to our new service type.
echo "vendor.samsung.hardware.snap.ISehSnap/default    u:object_r:hal_snap_stub_service:s0" \
    >> "$WORK_DIR/vendor/etc/selinux/vendor_service_contexts"

LOG_STEP_OUT
