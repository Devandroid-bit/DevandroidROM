SOURCE_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

# SEC_PRODUCT_FEATURE_GALLERY_CONFIG_PET_CLUSTER_VERSION
LOG_STEP_IN "- Adding SAIV pet clustering databases"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "vendor" "saiv/image_understanding/db/pet_detector" 0 2000 755 "u:object_r:vendor_snap_file:s0"
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE_PATH" "vendor" "saiv/image_understanding/db/pet_mypetsearch" 0 2000 755 "u:object_r:vendor_snap_file:s0"
LOG_STEP_OUT
