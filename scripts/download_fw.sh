#!/usr/bin/env bash
#
# Copyright (C) 2025 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

# [
source "$SRC_DIR/scripts/utils/firmware_utils.sh" || exit 1
source "$TOOLS_DIR/venv/bin/activate" || exit 1

FORCE=false

FIRMWARES=()
MODEL=""
CSC=""
IMEI=""
SERIAL_NO=""
LATEST_FIRMWARE=""
ZIP_FILE=""

PREPARE_SCRIPT()
{
    local EXTRA_FIRMWARES=()
    local IGNORE_SOURCE=false
    local IGNORE_TARGET=false

    while [ "$#" != 0 ]; do
        if [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--ignore-source" ]]; then
            IGNORE_SOURCE=true
        elif [[ "$1" == "--ignore-target" ]]; then
            IGNORE_TARGET=true
        elif [[ "$1" == "-"* ]]; then
            LOGE "Unknown option: $1"
            PRINT_USAGE
            exit 1
        else
            EXTRA_FIRMWARES+=("$1")
        fi

        shift
    done

    if ! $IGNORE_SOURCE; then
        _CHECK_NON_EMPTY_PARAM "SOURCE_FIRMWARE" "$SOURCE_FIRMWARE" || exit 1
        FIRMWARES+=("$SOURCE_FIRMWARE")

        IFS=':' read -r -a SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_EXTRA_FIRMWARES"
        if [ "${#SOURCE_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
            FIRMWARES+=("${SOURCE_EXTRA_FIRMWARES[@]}")
        fi
    fi

    if ! $IGNORE_TARGET; then
        _CHECK_NON_EMPTY_PARAM "TARGET_FIRMWARE" "$TARGET_FIRMWARE" || exit 1
        FIRMWARES+=("$TARGET_FIRMWARE")

        IFS=':' read -r -a TARGET_EXTRA_FIRMWARES <<< "$TARGET_EXTRA_FIRMWARES"
        if [ "${#TARGET_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
            FIRMWARES+=("${TARGET_EXTRA_FIRMWARES[@]}")
        fi
    fi

    if [ "${#EXTRA_FIRMWARES[@]}" -ge 1 ]; then
        FIRMWARES+=("${EXTRA_FIRMWARES[@]}")
    fi
}

PRINT_USAGE()
{
    echo "Usage: download_fw [options] <firmware>" >&2
    echo " --ignore-source : Skip parsing source firmware flags" >&2
    echo " --ignore-target : Skip parsing target firmware flags" >&2
    echo " -f, --force : Force firmware download" >&2
}

VERIFY_ODIN_PACKAGES()
{
    local FILE_NAME
    local LENGTH
    local STORED_HASH
    local CALCULATED_HASH

    while IFS= read -r f; do
        FILE_NAME="$(basename "$f")"
        LOG_STEP_IN "- Verifying $FILE_NAME..."

        FILE_NAME="${FILE_NAME%.md5}"

        # Samsung stores the output of `md5sum` at the very end of the file
        LENGTH="32" # Length of MD5 hash
        LENGTH="$((LENGTH + 2))" # 2 whitespace chars
        LENGTH="$((LENGTH + ${#FILE_NAME}))" # File name without .md5 extension
        LENGTH="$((LENGTH + 1))" # 1 newline char

        STORED_HASH="$(tail -c "$LENGTH" "$f" | cut -d " " -f 1 -s)"
        if [ ! "$STORED_HASH" ] || [[ "${#STORED_HASH}" != "32" ]]; then
            LOG "\033[0;31m! Expected hash could not be parsed\033[0m"
            exit 1
        fi

        CALCULATED_HASH="$(head -c-$LENGTH "$f" | md5sum | cut -d " " -f 1 -s)"

        if [[ "$STORED_HASH" != "$CALCULATED_HASH" ]]; then
            LOG "\033[0;31m! File is damaged\033[0m"
            exit 1
        fi

        LOG_STEP_OUT
    done < <(find "$ODIN_DIR/${MODEL}_${CSC}" -type f -name "*.md5")
}
# ]

PREPARE_SCRIPT "$@"

for i in "${FIRMWARES[@]}"; do
    PARSE_FIRMWARE_STRING "$i" || exit 1

    # Condition to apply manual Google Drive download exclusively for the source firmware
    if [[ "$i" == "$SOURCE_FIRMWARE" ]]; then
        LOG_STEP_IN "- Manually downloading SOURCE ($MODEL) firmware from Google Drive"

        ODIN_DIR="$OUT_DIR/odin"

        LOG "- Cleaning download directory..."
        [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ] && \
            rm -rf "$ODIN_DIR/${MODEL}_${CSC}"

        mkdir -p "$ODIN_DIR/${MODEL}_${CSC}"

        FILE_ID="1PKjPM2K7-eoAt5RCPYCcwQjOxPxDDk9J"
        ZIP_FILE="$ODIN_DIR/${MODEL}_${CSC}/firmware.zip"

        LOG "- Downloading firmware from Google Drive..."

        DOWNLOAD_URL="https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"

        curl \
            --fail \
            --location \
            --retry 5 \
            --retry-delay 3 \
            --retry-all-errors \
            --output "$ZIP_FILE" \
            "$DOWNLOAD_URL" || {
                LOGW "\033[0;31m! Failed to download firmware from Google Drive.\033[0m"
                rm -f "$ZIP_FILE"
                exit 1
            }

        if [ ! -s "$ZIP_FILE" ]; then
            LOGW "\033[0;31m! Download produced an empty file!\033[0m"
            rm -f "$ZIP_FILE"
            exit 1
        fi

        FILESIZE="$(stat -c%s "$ZIP_FILE" 2>/dev/null || stat -f%z "$ZIP_FILE")"

        LOG "- Downloaded file size: ${FILESIZE} bytes"

        # Detect Google Drive HTML/error pages.
        if head -c 512 "$ZIP_FILE" | grep -qiE '<!DOCTYPE html|<html'; then
            LOGW "\033[0;31m! Google Drive returned an HTML page instead of the firmware file.\033[0m"
            rm -f "$ZIP_FILE"
            exit 1
        fi

        # Verify that the downloaded file is a valid ZIP archive.
        if ! unzip -tq "$ZIP_FILE" >/dev/null 2>&1; then
            LOGW "\033[0;31m! Downloaded file is not a valid ZIP archive.\033[0m"
            rm -f "$ZIP_FILE"
            exit 1
        fi

        LOG "- Firmware successfully downloaded."

        LOG "- Extracting $(basename "$ZIP_FILE")..."
        EVAL "unzip -o \"$ZIP_FILE\" -d \"$ODIN_DIR/${MODEL}_${CSC}\" && rm -f \"$ZIP_FILE\"" || exit 1

        # FIX: Dynamically determine version from the AP file and create the missing .downloaded flag
        AP_FILE="$(find "$ODIN_DIR/${MODEL}_${CSC}" -name "AP_*.md5" | head -n 1)"
        if [ -n "$AP_FILE" ]; then
            FW_VERSION="$(basename "$AP_FILE" | cut -d'_' -f 2)"
            echo -n "$FW_VERSION" > "$ODIN_DIR/${MODEL}_${CSC}/.downloaded"
        else
            echo -n "UNKNOWN_VERSION" > "$ODIN_DIR/${MODEL}_${CSC}/.downloaded"
        fi

        LOG "- Firmware extraction completed successfully."

        LOG_STEP_OUT

    else
        # TARGET firmware: samloader-rs
        LATEST_FIRMWARE="$(GET_LATEST_FIRMWARE "$MODEL" "$CSC")"
        if [ ! "$LATEST_FIRMWARE" ]; then
            LOGE "Latest available firmware could not be fetched"
            exit 1
        fi

        LOG_STEP_IN "- Processing TARGET $MODEL firmware with $CSC CSC"
        LOG "- Downloaded firmware: $(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" 2>/dev/null)"
        LOG "- Extracted firmware: $(cat "$FW_DIR/${MODEL}_${CSC}/.extracted" 2>/dev/null)"
        LOG "- Latest available firmware: $LATEST_FIRMWARE"

        LOG_STEP_IN

        if ! $FORCE; then
            if [ -f "$FW_DIR/${MODEL}_${CSC}/.extracted" ]; then
                if COMPARE_SEC_BUILD_VERSION \
                    "$(cat "$FW_DIR/${MODEL}_${CSC}/.extracted")" \
                    "$LATEST_FIRMWARE"; then
                    LOG "\033[0;33m! This firmware has already been extracted, skipping\033[0m"
                    LOG_STEP_OUT
                    LOG_STEP_OUT
                    continue
                fi
            fi

            if [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ]; then
                if ! COMPARE_SEC_BUILD_VERSION \
                    "$(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded")" \
                    "$LATEST_FIRMWARE"; then
                    LOG "\033[0;33m! A newer firmware is available for download, use --force flag if you want to overwrite it\033[0m"
                else
                    LOG "\033[0;33m! This firmware has already been downloaded\033[0m"
                fi

                LOG_STEP_OUT
                LOG_STEP_OUT
                continue
            fi
        fi

        LOG "- Downloading firmware..."

        [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ] && \
            rm -rf "$ODIN_DIR/${MODEL}_${CSC}"

        mkdir -p "$ODIN_DIR/${MODEL}_${CSC}"

        COUNT=1

        while true; do
            (
                cd "$OUT_DIR"

                SAMLOADER_VERSION="$LATEST_FIRMWARE"

                # Preserve the existing SM-S731B target version override.
                if [ "$MODEL" == "SM-S731B" ]; then
                    SAMLOADER_VERSION="S731BXXU1AYH9/S731BOXM1AYH9/S731BXXU1AYH9/S731BXXU1AYH9"
                fi

                samloader \
                    -m "$MODEL" \
                    -r "$CSC" \
                    -v "$SAMLOADER_VERSION" \
                    -j 8 \
                    -d "$ODIN_DIR/${MODEL}_${CSC}" || exit 1
            )

            ZIP_FILE="$(find "$ODIN_DIR/${MODEL}_${CSC}" \
                -type f -name "*.zip" | sort -r | head -n 1)"

            if [ ! "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
                if [ "$COUNT" -gt 10 ]; then
                    LOGW "\033[0;31m! Download failed after 10 attempts.\033[0m"
                    exit 1
                fi

                LOGW "\033[0;31m! [Attempt: $COUNT] Download failed, retrying in 5 seconds...\033[0m"

                sleep 5
                ((COUNT++))
            else
                break
            fi
        done

        LOG "- Extracting $(basename "$ZIP_FILE")..."

        EVAL "unzip -o \"$ZIP_FILE\" -d \"$ODIN_DIR/${MODEL}_${CSC}\" && rm -rf \"$ZIP_FILE\"" || exit 1

        VERIFY_ODIN_PACKAGES

        echo -n "$LATEST_FIRMWARE" > "$ODIN_DIR/${MODEL}_${CSC}/.downloaded"

        LOG_STEP_OUT
        LOG_STEP_OUT
    fi
done

deactivate

exit 0
