function ghc-upgrade
  if set -q SSH_CONNECTION; or set -q SSH_CLIENT; or set -q SSH_TTY
    bash $HOME/.config/guanghechen/nix-remote/setup.sh
    return
  else

    if test (uname) = Darwin
      bash $HOME/.config/guanghechen/osx/setup.sh
    else
      bash $HOME/.config/guanghechen/nix/setup.sh
    end
  end
end
