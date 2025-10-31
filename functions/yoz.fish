function yoz --description "Preview file with yoz"
    # Handle auth subcommand
    if test (count $argv) -gt 0 && test "$argv[1]" = auth
        set -l env_file $HOME/.config/yoz/.env.local

        if not test -f $env_file
            set_color red
            echo "Error: $env_file not found"
            set_color normal
            return 1
        end

        set -l token (grep '^YOZ_AUTH_TOKEN=' $env_file | cut -d= -f2-)

        if test -z "$token"
            set_color red
            echo "Error: YOZ_AUTH_TOKEN not found in $env_file"
            set_color normal
            return 1
        end

        # Copy to clipboard based on platform
        if command -v pbcopy >/dev/null
            # macOS
            echo -n $token | pbcopy
        else if command -v xclip >/dev/null
            # Linux/WSL with xclip
            echo -n $token | xclip -selection clipboard
        else if command -v wl-copy >/dev/null
            # Wayland (some Linux distros)
            echo -n $token | wl-copy
        else if test -n "$WSL_DISTRO_NAME" && command -v clip.exe >/dev/null
            # WSL with clip.exe
            echo -n $token | clip.exe
        else
            set_color red
            echo "Error: No clipboard tool found (tried pbcopy, xclip, wl-copy, clip.exe)"
            set_color normal
            return 1
        end

        set_color green
        echo "YOZ_AUTH_TOKEN copied to clipboard"
        set_color normal
        return 0
    end

    set -l filepath ""
    set -l force false

    # Parse force options first
    for arg in $argv
        switch $arg
            case --force --force=true
                set force true
            case --force=false
                set force false
        end
    end

    # Filter out force options to get remaining args
    set -l remaining_args
    for arg in $argv
        switch $arg
            case --force --force=true --force=false
                # Skip force options
            case '*'
                set remaining_args $remaining_args $arg
        end
    end

    # Read piped input if no filepath provided and stdin is available
    if test (count $remaining_args) -eq 0 && not isatty stdin
        while read line
            test -z "$filepath" && set filepath $line && break
        end
    end

    # Parse remaining arguments for filepath
    for arg in $remaining_args
        switch $arg
            case '--*'
                echo "Unknown option: $arg" && return 1
            case '*'
                test -z "$filepath" && set filepath $arg || begin
                    echo "Multiple filepaths provided" && return 1
                end
        end
    end

    test -z "$filepath" && begin
        echo "Usage: yoz <filepath> [--force] [--force=true] [--force=false]"
        echo "       yoz auth"
        return 1
    end

    test -z "$YOZ_SERVER_PORT" && begin
        echo "Error: YOZ_SERVER_PORT not set"
        return 1
    end

    set -l url "https://localhost:$YOZ_SERVER_PORT/api/file/switch?filepath="(string escape --style=url (realpath $filepath))"&force=$force"
    # echo "curl -k -X POST $url"
    curl -k -X POST $url >/dev/null 2>&1 &
end
