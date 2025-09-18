# Setup path
fish_add_path --append /mnt/c/WINDOWS/System32/
fish_add_path --append /mnt/c/WINDOWS
fish_add_path --append "/mnt/c/Program Files/PowerShell/7/"

## Aliases
alias chmod='chmod --preserve-root' # the `--preserve-root` option not worked in MacOS.
alias code='env -u TMUX -u TERM /mnt/c/app/vscode/bin/code'
alias cursor='env -u TMUX -u TERM /mnt/c/app/cursor/resources/app/bin/cursor'
alias pbpaste="powershell.exe Get-Clipboard >"

## Abbr
abbr -a ghc-gen-secret "node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | clip.exe"

## Setup vpn
if command -v ipconfig.exe >/dev/null
    set -gx ghc_vpn_host_ip (ipconfig.exe | grep 'IPv4 Address' | awk '{print $NF}' | grep 192 | head -1 | sed 's/[^0-9.]//g')
else
    set -gx ghc_vpn_host_ip (cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v '::' | head -1)
end

## functions
function open
    if test (count $argv) -eq 0
        echo "Usage: open <path>"
        return 1
    end

    set winpath (wslpath -w $argv[1])
    explorer.exe "$winpath"
end

function start
    if test (count $argv) -eq 0
        echo "Usage: open <path>"
        return 1
    end

    set winpath (wslpath -w $argv[1])
    cmd.exe /c start "" "$winpath"
end
