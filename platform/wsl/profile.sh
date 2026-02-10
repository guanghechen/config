# WSL login env

if ! declare -F _add_path >/dev/null 2>&1; then
    _add_path() {
        [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
    }
fi

_add_path "/mnt/c/Program Files/PowerShell/7/"
_add_path "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/"
_add_path "/mnt/c/WINDOWS/System32/"
_add_path "/mnt/c/WINDOWS/"

export BROWSER="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

if [[ -n "${GHC_WINDOWS_USERNAME:-}" ]]; then
    export f_windows_terminal_settings="/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    export f_windows_download="/mnt/c/Users/$GHC_WINDOWS_USERNAME/Downloads"
    export f_vscode_keybindings="/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Roaming/Code/User/keybindings.json"
fi

export ghc_vpn_host_ip="127.0.0.1"
if command -v ipconfig.exe >/dev/null 2>&1; then
    detected_ip="$(ipconfig.exe | awk -F: '/IPv4 Address/ {gsub(/[^0-9.]/, "", $2); if ($2 ~ /^192\./) {print $2; exit}}')"
else
    detected_ip="$(awk '/^nameserver/ && $2 !~ /::/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)"
fi
if [[ -n "$detected_ip" ]]; then
    export ghc_vpn_host_ip="$detected_ip"
fi
