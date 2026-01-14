function ghc-winshark-vsc
    if test -z "$d_wireshark_vsc_log"
        printf "\e[91m  Error: d_wireshark_vsc_log is not set or empty\e[0m\n" >&2
        return 1
    end

    if test -e "$d_wireshark_vsc_log" -a ! -d "$d_wireshark_vsc_log"
        printf "\e[91m  Error: d_wireshark_vsc_log exists but is not a directory: %s\e[0m\n" "$d_wireshark_vsc_log" >&2
        return 1
    end

    if test ! -d "$d_wireshark_vsc_log"
        if not mkdir -p "$d_wireshark_vsc_log" 2>/dev/null
            printf "\e[91m  Error: Failed to create directory (permission denied): %s\e[0m\n" "$d_wireshark_vsc_log" >&2
            return 1
        end
    end

    set f_wireshark_vsc_log "$d_wireshark_vsc_log/vsc.log"
    set -x SSLKEYLOGFILE "$f_wireshark_vsc_log"
    set -x NODE_OPTIONS "--tls-keylog=$f_wireshark_vsc_log"
end
