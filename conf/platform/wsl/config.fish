# Setup path
fish_add_path --append "/mnt/c/Program Files/PowerShell/7/"
fish_add_path --append "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/"
fish_add_path --append /mnt/c/WINDOWS/System32/
fish_add_path --append /mnt/c/WINDOWS/

## Envs
set -gx BROWSER "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
set -gx f_windows_terminal_settings "/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
set -gx f_windows_download "/mnt/c/Users/$GHC_WINDOWS_USERNAME/Downloads"
set -gx f_vscode_keybindings "/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Roaming/Code/User/keybindings.json"
set -gx f_vscode_settings "/mnt/c/Users/$GHC_WINDOWS_USERNAME/AppData/Roaming/Code/User/settings.json"

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

## Load WSL-specific functions (lazy load like fish functions/)
set -l wsl_fn_dir (dirname (status filename))/fn
if test -d $wsl_fn_dir
    set -a fish_function_path $wsl_fn_dir
end
