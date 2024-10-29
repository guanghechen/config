function ghc-theme-gen
  set script_path "$HOME/.config/guanghechen/config/theme/gen_themes.mjs"
  if test -f "$script_path"
    node "$script_path"
  else
    echo "Cannot find $script_path."
  end
end
