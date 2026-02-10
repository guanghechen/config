# shellcheck shell=bash
# ghc-winshark-vsc - Set up SSL key logging for VS Code debugging with Wireshark

ghc-winshark-vsc() {
    if [[ -z "$d_wireshark_vsc_log" ]]; then
        printf "\e[91m  Error: d_wireshark_vsc_log is not set or empty\e[0m\n" >&2
        return 1
    fi

    if [[ -e "$d_wireshark_vsc_log" && ! -d "$d_wireshark_vsc_log" ]]; then
        printf "\e[91m  Error: d_wireshark_vsc_log exists but is not a directory: %s\e[0m\n" "$d_wireshark_vsc_log" >&2
        return 1
    fi

    if [[ ! -d "$d_wireshark_vsc_log" ]]; then
        if ! mkdir -p "$d_wireshark_vsc_log" 2>/dev/null; then
            printf "\e[91m  Error: Failed to create directory (permission denied): %s\e[0m\n" "$d_wireshark_vsc_log" >&2
            return 1
        fi
    fi

    local f_wireshark_vsc_log="$d_wireshark_vsc_log/vsc.log"
    export SSLKEYLOGFILE="$f_wireshark_vsc_log"
    export NODE_OPTIONS="--tls-keylog=$f_wireshark_vsc_log"
}
