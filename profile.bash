# Login entry retained for existing ~/.bash_profile installations.
if [[ -z "${__BASH_CONFIG_LOADED:-}" ]]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/bash/config.bash"
fi
