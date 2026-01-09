function open
    if test (count $argv) -eq 0
        echo "Usage: open <url|path>"
        return 1
    end

    set -l target $argv[1]
    if string match -qr '^https?://' -- $target
        explorer.exe "$target"
    else if string match -qr '^file://' -- $target
        set -l filepath (string replace 'file://' '' -- $target)
        set -l winpath (wslpath -w $filepath)
        explorer.exe "file://$winpath"
    else
        set -l winpath (wslpath -w $target)
        explorer.exe "$winpath"
    end
end
