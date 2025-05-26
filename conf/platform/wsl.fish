## Aliases
alias chmod='chmod --preserve-root' # the `--preserve-root` option not worked in MacOS.
alias code='env -u TMUX -u TERM /mnt/c/app/vscode/bin/code'
alias open="explorer.exe"
alias pbpaste="powershell.exe Get-Clipboard >"

## Setup vpn
if command -v ipconfig.exe >/dev/null
    set -gx ghc_vpn_host_ip (ipconfig.exe | grep 'IPv4 Address' | awk '{print $NF}' | grep 192 | head -1 | sed 's/[^0-9.]//g')
else
    set -gx ghc_vpn_host_ip (cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v '::' | head -1)
end
