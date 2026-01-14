function ghc-theme-apply
  set script_path "$HOME/.config/guanghechen/config/theme/apply_theme.mjs"
  if test -f "$script_path"
    set first_arg $argv[1]
    set first_arg (string trim -- $first_arg | string lower)

    node "$script_path" "$first_arg"
  else
    printf "\e[91m  Cannot find %s.\e[0m\n" "$script_path"
  end
end
