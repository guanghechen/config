function ghc-opensource --description 'Clone or pull an opensource repository'
    if test (count $argv) -eq 0
        printf "\e[93m  Usage: ghc-opensource [--github] <author/reponame>\e[0m\n"
        return 1
    end

    if not set -q ROOT_SOURCECODES
        printf "\e[91m  Error: ROOT_SOURCECODES is not set\e[0m\n"
        return 1
    end

    set -l platform --github
    set -l repo_path

    switch $argv[1]
        case --github
            set platform --github
            set repo_path $argv[2]
        case '*'
            set repo_path $argv[1]
    end

    if test -z "$repo_path"
        printf "\e[93m  Usage: ghc-opensource [--github] <author/reponame>\e[0m\n"
        return 1
    end

    switch $platform
        case --github
            set -l parts (string split '/' $repo_path)
            if test (count $parts) -ne 2
                printf "\e[91m  Error: Invalid format. Expected <author/reponame>\e[0m\n"
                return 1
            end

            set -l author $parts[1]
            set -l reponame $parts[2]
            set -l target_dir "$ROOT_SOURCECODES/github/$author/$reponame"

            if test -d "$target_dir/.git"
                git -C "$target_dir" pull origin || return 1
                cd "$target_dir"
                return 0
            end

            set -l parent_dir "$ROOT_SOURCECODES/github/$author"
            mkdir -p "$parent_dir" || return 1
            git -C "$parent_dir" clone "https://github.com/$author/$reponame.git" || return 1
            cd "$target_dir"
    end
end
