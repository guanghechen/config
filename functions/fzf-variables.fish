function fzf-variables --description "Search shell variables and insert name"
    set -l set_show (set --show | psub)
    set -l var_names (set --names | string match --invert history)

    set -l token (commandline --current-token)
    set -l query (string replace -- '$' '' $token)

    set -l selected (
        printf '%s\n' $var_names |
        fzf --multi --prompt="Variables> " --query=$query \
            --preview-window="wrap" \
            --preview="string match --regex '^\\\${1}(?::|\\[).*' <$set_show | string replace --regex '^\\\${1}(?:: )?' ''"
    )

    if test $status -eq 0
        if string match --quiet -- '$*' $token
            commandline --current-token --replace (string join " " \${$selected})
        else
            commandline --current-token --replace (string join " " $selected)
        end
    end

    commandline --function repaint
end
