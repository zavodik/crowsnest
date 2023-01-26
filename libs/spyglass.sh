#!/bin/bash

#### spyglass library

#### crowsnest - A webcam Service for multiple Cams and Stream Services.
####
#### Written by Stephan Wendel aka KwadFan <me@stephanwe.de>
#### Copyright 2021
#### https://github.com/mainsail-crew/crowsnest
####
#### This File is distributed under GPLv3
####

# shellcheck enable=require-variable-braces

# Exit upon Errors
set -Ee

## Helper Funcs
get_os_version() {
    grep -c "bullseye" /etc/os-release
}

get_libcamera_support() {
    vcgencmd get_camera | grep -c "libcamera interfaces=1"
}

check_spyglass_env() {
    local cam_sec
    cam_sec="${1}"
    # check bullseye
    if [[ $(get_os_version) = "0" ]]; then
        log_msg "ERROR: Mode 'mjpg-spyglass' only works on 'bullseye' distributions!"
        log_msg "INFO: Skip starting spyglass ..."
        return
    fi

    # check libcamera support
    if [[ $(get_libcamera_support) = "0" ]]; then
        log_msg "ERROR: No libcamera support or device not supported by libcamera!"
        log_msg "INFO: Skip starting spyglass ..."
        return
    fi

    # check python3
    if [[ -z "$(command -v python3)" ]]; then
        log_msg "ERROR: 'python3' not found! Needed by spyglass..."
        log_msg "INFO: Skip starting spyglass ..."
        return
    fi

    if [[ $(get_os_version) != "0" ]] &&
        [[ $(get_libcamera_support) = "1" ]]; then
        run_spyglass "${cam_sec}"
    fi
}

run_spyglass() {
    local cam_sec pt res fps cstm start_param spgl_bin
    cam_sec="${1}"
    spgl_bin="${BASE_CN_PATH}/bin/spyglass/run.py"
    pt=$(get_param "cam ${cam_sec}" port)
    res=$(get_param "cam ${cam_sec}" resolution)
    fps=$(get_param "cam ${cam_sec}" max_fps)
    noprx="$(get_param "crowsnest" no_proxy 2> /dev/null)"
    # construct start parameter
    if [[ -n "${noprx}" ]] && [[ "${noprx}" = "true" ]]; then
        start_param=( --bindaddress 0.0.0.0 -p "${pt}" )
        log_msg "INFO: Set to 'no_proxy' mode! Using 0.0.0.0 !"
    else
        start_param=( --bindaddress 127.0.0.1 -p "${pt}" )
    fi

    # Set Port
    start_param+=( --port "${pt}" )


    # Set FPS & Resolution
    start_param+=( --resolution "${res}" --fps "${fps}" )

    # Set fallback urls, matching to URLs in crowsnest.conf
    start_param+=( --stream_url /?action=stream )
    start_param+=( --snapshot_url /?action=snapshot )

    # Custom Flag Handling (append to defaults)
    if [[ -n "${cstm}" ]]; then
        start_param+=( "${cstm}" )
    fi
    # Log start_param
    log_msg "Starting spyglass ..."
    echo "Parameters: ${start_param[*]}" | \
    log_output "spyglass [cam ${cam_sec}]"
    # Start ustreamer
    echo "${start_param[*]}" | xargs "${spgl_bin}" 2>&1 | \
    log_output "spyglass [cam ${cam_sec}]"
    # Should not be seen else failed.
    log_msg "ERROR: Start of spyglass [cam ${cam_sec}] failed!"
}
