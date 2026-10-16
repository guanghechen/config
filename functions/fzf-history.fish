# Upstream reference: https://github.com/PatrickF1/fzf.fish/blob/main/functions/_fzf_search_history.fish
# Locally adapted; see README.md for sync policy.

function fzf-history --description "Search command history"
    test -z "$fish_private_mode" && builtin history merge

    set -l time_fmt "%m-%d %H:%M:%S"
    set -l selected (
        builtin history --null --show-time="$time_fmt │ " |
        fzf --read0 --print0 --multi --scheme=history --prompt="History> " \
            --with-shell='fish --no-config -c' --bind=ctrl-o:ignore \
            --query=(commandline | string collect) \
            --preview="string split --max=1 --fields=2 -- ' │ ' {} | fish_indent --ansi" \
            --preview-window="bottom:3:wrap" |
        string split0
    )

    test $status -eq 0 && commandline --replace -- (string split --max=1 --fields=2 -- ' │ ' $selected)
    commandline --function repaint
end
