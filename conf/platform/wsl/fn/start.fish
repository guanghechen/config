function start
    if test (count $argv) -eq 0
        echo "Usage: start <path>"
        return 1
    end

    set winpath (wslpath -w $argv[1])
    cmd.exe /c start "" "$winpath"
end
