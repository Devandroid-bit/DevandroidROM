LOG_STEP_IN "- Adding SNAP AIDL stub service"

# bin/snap_stub and etc/init/vendor.snap_stub.rc are already handled
# automatically by the mod loader's vendor/ folder auto-copy -- do not
# ADD_TO_WORK_DIR them again here.

DELETE_FROM_WORK_DIR "vendor" "etc/init/vendor.samsung.hardware.snap-lazy.rc"

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

(allow init hal_snap_stub_exec (file (getattr open read execute execute_no_trans map)))
(typetransition init hal_snap_stub_exec process hal_snap_stub)

(allow hal_snap_stub binder_device (chr_file (read write open ioctl map)))
(allow hal_snap_stub servicemanager (binder (call transfer)))
(allow hal_snap_stub self (binder (call transfer)))
(allow hal_snap_stub hal_snap_stub_service (service_manager (add find)))
EOF

echo "vendor.samsung.hardware.snap.ISehSnap/default    u:object_r:hal_snap_stub_service:s0" \
    >> "$WORK_DIR/vendor/etc/selinux/vendor_service_contexts"

LOG_STEP_OUT
