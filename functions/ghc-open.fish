function ghc-open
  if grep -qiE "microsoft|wsl" /proc/version
    set -l path $argv[1]
    if test -z "$path"
        echo "Usage: ghc-open <path>"
        return 1
    end
    explorer.exe $path
  end
end

