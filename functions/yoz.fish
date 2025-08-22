function yoz --description "Preview file with yozora"
    set -l filepath ""
    set -l force false

    for arg in $argv
        switch $arg
            case --force --force=true
                set force true
            case --force=false
                set force false
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

    test -z "$YOZORA_SERVER_PORT" && begin
        echo "Error: YOZORA_SERVER_PORT not set"
        return 1
    end

    set -l url "http://localhost:$YOZORA_SERVER_PORT/api/file-switch?filepath="(string escape --style=url (realpath $filepath))"&force=$force"
    curl -X POST $url >/dev/null 2>&1 &
end
