function ghc-theme-gen
  set script_path "$HOME/.config/guanghechen/cli/theme.mjs"
  if test -f "$script_path"
    node "$script_path" gen
  else
    printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
  end
end
