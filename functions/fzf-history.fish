function fzf-history --description "Search command history"
    test -z "$fish_private_mode" && builtin history merge

    set -l time_fmt "%m-%d %H:%M:%S"
    set -l time_regex '^.*? │ '
    set -l selected (
        builtin history --null --show-time="$time_fmt │ " |
        fzf --read0 --print0 --multi --scheme=history --prompt="History> " \
            --query=(commandline) \
            --preview="string replace --regex '$time_regex' '' -- {} | fish_indent --ansi" \
            --preview-window="bottom:3:wrap" |
        string split0 |
        string replace --regex $time_regex ''
    )

    test $status -eq 0 && commandline --replace -- $selected
    commandline --function repaint
end
