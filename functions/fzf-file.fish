# Upstream reference: https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_search_directory.fish
# Locally adapted; see README.md for sync policy.

function fzf-file --description "Search files in current directory"
    set -l token (commandline --tokens-expanded --current-token | string collect)
    set -l search_dir .
    set -l prompt 'File> '
    set -l query "$token"

    if string match --quiet -- '*/' "$token" && test -d "$token"
        set search_dir "$token"
        set prompt "$token> "
        set query ''
    end

    # fd includes the search directory in each result; fzf quotes complete paths.
    set -l result (
        command fd --hidden --follow --no-ignore-vcs --color=always --print0 \
            --exclude=.git --exclude=node_modules --exclude=.DS_Store \
            --exclude='*.local' --exclude=local/ --exclude='*.exe' --exclude='*.zip' \
            --type=f --search-path="$search_dir" |
        fzf --ansi --read0 --print0 --multi --prompt="$prompt" --query="$query" \
            --with-shell='fish --no-config -c' \
            --preview='bat --line-range=:500 --style=snip --theme=vsc-light-modern --number --color=always -- {} || cat -n -- {}' \
            --bind='ctrl-o:execute(nvim -- {+} < /dev/tty)' |
        string split0
    )

    test $status -eq 0 && commandline --current-token --replace -- (string escape -- $result | string join ' ')
    commandline --function repaint
end
