function yoz --description "Preview file with yoz"
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
        return 1
    end

    test -z "$YOZ_SERVER_PORT" && begin
        echo "Error: YOZ_SERVER_PORT not set"
        return 1
    end

    set -l url "http://localhost:$YOZ_SERVER_PORT/api/file-switch?filepath="(string escape --style=url (realpath $filepath))"&force=$force"
    curl -X POST $url >/dev/null 2>&1 &
end
