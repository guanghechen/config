function ghc-theme-gen
  set script_path "$HOME/.config/guanghechen/config/theme/gen_themes.mjs"
  if test -f "$script_path"
    node "$script_path"
  else
    printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
  end
end
