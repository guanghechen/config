function fzf-file --description "Search files in current directory"
    set -l token (commandline --current-token)
    set -l expanded (eval echo -- $token)
    set -l unescaped (string unescape -- $expanded)

    if string match --quiet -- "*/" $unescaped && test -d "$unescaped"
        set -l result (
            fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --type=f --base-directory=$unescaped |
            fzf --ansi --multi --prompt="$unescaped> " --preview="bat --style=numbers --color=always $unescaped{}"
        )
        test $status -eq 0 && commandline --current-token --replace -- $unescaped(string escape -- $result | string join ' ')
    else
        set -l result (
            fd --hidden --follow --no-ignore-vcs --color=always --exclude=.git --exclude='*.local' --exclude=local/ --type=f |
            fzf --ansi --multi --prompt="File> " --query="$unescaped" --preview="bat --style=numbers --color=always {}"
        )
        test $status -eq 0 && commandline --current-token --replace -- (string escape -- $result | string join ' ')
    end

    commandline --function repaint
end
