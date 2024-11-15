function ghc-upgrade
  if test (uname) = "Darwin"
    bash $HOME/.config/guanghechen/osx/setup.sh
  else
    bash $HOME/.config/guanghechen/nix/setup.sh
  end
end

