function ghc-pbpaste
  if test -e /proc/version
    if grep -qiE "microsoft|wsl" /proc/version
      set -l filepath $argv[1]
      if test -z "$filepath"
          echo "Usage: ghc-pbpaste <filepath>"
          return 1
      end
      powershell.exe Get-Clipboard > $filepath
    end
  end
end

