function fish_mode_prompt --description 'Request extended keys mode 2 for tmux'
    if test -n "$TMUX"
        printf '\e[>4;2m'
    end
end
