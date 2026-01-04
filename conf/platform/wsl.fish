# Setup path
fish_add_path --append /mnt/c/WINDOWS/System32/
fish_add_path --append /mnt/c/WINDOWS
fish_add_path --append "/mnt/c/Program Files/PowerShell/7/"

## Aliases
alias chmod='chmod --preserve-root' # the `--preserve-root` option not worked in MacOS.
alias pbpaste="powershell.exe Get-Clipboard >"

if test -e /mnt/c/app/vscode/bin/code
    if set -q TMUX
        alias code='env -u TMUX -u TERM /mnt/c/app/vscode/bin/code'
    else
        alias code='/mnt/c/app/vscode/bin/code'
    end
else if test -e /mnt/d/app/vscode/bin/code
    if set -q TMUX
        alias code='env -u TMUX -u TERM /mnt/d/app/vscode/bin/code'
    else
        alias code='/mnt/d/app/vscode/bin/code'
    end
end

## Abbr
abbr -a ghc-gen-secret "node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | clip.exe"
abbr -a ghc-invisible-space "node -e \"process.stdout.write('\u00A0')\" | clip.exe"

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
