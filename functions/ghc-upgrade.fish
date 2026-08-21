function ghc-upgrade
    set -l config_root "$HOME/.config/guanghechen"
    if set -q XDG_CONFIG_HOME
        set config_root "$XDG_CONFIG_HOME/guanghechen"
    end
    if set -q GHC_CONFIG_ROOT
        set config_root "$GHC_CONFIG_ROOT"
    end

    set -l edition ""
    if type -q kit-repo
        set edition (kit-repo get config.edition 2>/dev/null | string trim)
    end

    if test -z "$edition"
        if set -q SSH_CONNECTION; or set -q SSH_CLIENT; or set -q SSH_TTY
            set edition nix-remote
        else if test (uname) = Darwin
            set edition osx
        else
            set edition nix
        end
    end

    switch $edition
        case nix-remote
            bash "$config_root/setup/nix-remote/setup.bash"
        case osx
            bash "$config_root/setup/osx/setup.bash"
        case win
            pwsh -File "$config_root/setup/win/setup.ps1"
        case '*'
            bash "$config_root/setup/nix/setup.bash"
    end
end
