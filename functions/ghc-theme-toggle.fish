function ghc-theme-toggle
  set script_path "$HOME/.config/guanghechen/config/theme/toggle_theme.mjs"
  if test -f "$script_path"
    set first_arg $argv[1]
    set first_arg (string trim -- $first_arg | string lower)

    node "$script_path" "$first_arg"
  else
    echo "Cannot find $script_path."
  end
end
