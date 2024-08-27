#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=nx611j
VENDOR=nubia

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib/hw/camera.sdm660.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
        vendor/lib/libNubiaImageAlgorithm.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libNubiaImageAlgorithmShim.so" "${2}"
            "${PATCHELF}" --remove-needed "libjnigraphics.so" "${2}"
            "${PATCHELF}" --remove-needed "libnativehelper.so" "${2}"
            "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
        vendor/lib/libmmcamera_ppeiscore.so|vendor/lib/libmmcamera_bokeh.so|vendor/lib/libnubia_effect.so|vendor/lib64/libnubia_effect.so|vendor/lib64/libnubia_media_player.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --remove-needed "libandroid.so" "${2}"
            "${PATCHELF}" --remove-needed "libgui.so" "${2}"
            ;;
        vendor/lib64/libnubia_media_player.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --remove-needed "libandroid_runtime.so" "${2}"
            ;;
        vendor/lib64/hw/fingerprint.sunwave.sdm660.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --remove-needed "libunwind.so" "${2}"
            "${PATCHELF}" --remove-needed "libbacktrace.so" "${2}"
            ;;
        vendor/lib64/libarcsoft_beautyshot_image_algorithm.so | vendor/lib64/libarcsoft_night_shot.so | vendor/lib64/libarcsoft_beautyshot_video_algorithm.so | vendor/lib64/libarcsoft_beautyshot.so | vendor/lib64/libtrueportrait.so | vendor/lib/libarcsoft_beautyshot_image_algorithm.so | vendor/lib/libmmcamera_hdr_gb_lib.so | vendor/lib/libcalibverify.so | vendor/lib/libarcsoft_high_dynamic_range.so | vendor/lib/libarcsoft_night_shot.so | vendor/lib/libvideobokeh.so | vendor/lib/liboptizoom.so | vendor/lib/libdualcameraddm.so | vendor/lib/libarcsoft_dualcam_verification.so | vendor/lib/libarcsoft_beautyshot_video_algorithm.so | vendor/lib/libarcsoft_beautyshot.so | vendor/lib/libchromaflash.so | vendor/lib/libtrueportrait.so | vendor/lib/libarcsoft_dualcam_refocus.so | vendor/lib/libseemore.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF_0_17_2}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;
        vendor/bin/pm-service)
            [ "$2" = "" ] && return 0
            grep -q libutils-v33.so "${2}" || "${PATCHELF}" --add-needed "libutils-v33.so" "${2}"
            ;;
        system_ext/lib64/lib-imsvideocodec.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            "${PATCHELF}" --replace-needed "libqdMetaData.so" "libqdMetaData.system.so" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        vendor/lib64/libril-qc-hal-qmi.so)
            [ "$2" = "" ] && return 0
            for v in 1.{0..2}; do
                sed -i "s|android.hardware.radio.config@${v}.so|android.hardware.radio.c_shim@${v}.so|g" "${2}"
            done
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

extract "${MY_DIR}/proprietary-files-nubia.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
