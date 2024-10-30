function ghc-pbpaste
  if grep -qiE "microsoft|wsl" /proc/version
    set -l filepath $argv[1]
    if test -z "$filepath"
        echo "Usage: ghc-pbpaste <filepath>"
        return 1
    end
    powershell.exe Get-Clipboard > $filepath
  end
end

