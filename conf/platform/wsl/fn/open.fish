function open
    if test (count $argv) -eq 0
        echo "Usage: open <path>"
        return 1
    end

    set winpath (wslpath -w $argv[1])
    explorer.exe "$winpath"
end
