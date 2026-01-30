function ghc-upgrade
    set -l config_root "$HOME/.config/guanghechen"
    if set -q XDG_CONFIG_HOME
        set config_root "$XDG_CONFIG_HOME/guanghechen"
    end
    if set -q GHC_CONFIG_ROOT
        set config_root "$GHC_CONFIG_ROOT"
    end

    set -l edition ""
    if type -q node
        set edition (node "$config_root/config/_shared/setting.mjs" --print-edition 2>/dev/null | string trim)
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
            bash "$config_root/nix-remote/setup.sh"
        case osx
            bash "$config_root/osx/setup.sh"
        case win
            pwsh -File "$config_root/win/setup.ps1"
        case '*'
            bash "$config_root/nix/setup.sh"
    end
end
