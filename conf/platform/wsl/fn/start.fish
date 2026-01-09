function start
    if test (count $argv) -eq 0
        echo "Usage: start <url|path>"
        return 1
    end

    set -l target $argv[1]
    if string match -qr '^https?://' -- $target
        cmd.exe /c start "" "$target"
    else if string match -qr '^file://' -- $target
        set -l filepath (string replace 'file://' '' -- $target)
        set -l winpath (wslpath -w $filepath)
        cmd.exe /c start "" "file://$winpath"
    else
        set -l winpath (wslpath -w $target)
        cmd.exe /c start "" "$winpath"
    end
end
