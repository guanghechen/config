# Interactive entry retained for existing ~/.bashrc installations.
[[ $- == *i* ]] || return 0
if [[ -z "${__BASH_CONFIG_LOADED:-}" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/bash/config.bash"
fi
