## Arrow Keys

zsh need to unbind arrow related keys.

```zsh
## unbind keys
bindkey -r "^[OA"
bindkey -r "^[OB"
bindkey -r "^[OC"
bindkey -r "^[OD"
bindkey -r "^[[1;5A"
bindkey -r "^[[1;5B"
bindkey -r "^[[1;5C"
bindkey -r "^[[1;5D"
bindkey -r "^[[A"
bindkey -r "^[[B"
bindkey -r "^[[C"
bindkey -r "^[[D"
```

## Cross-platform

```bash
cp ~/.config/alacritty/platform/macos.toml ~/.config/alacritty/local/macos.toml
```

## Change icon


* Macos
  1. Open Macos Terminal, and right click on the terminal icon from the dock: Options --> Show in Finder
  2. Right click on temrinal icon from the finder: Get Info
  3. Click the left top icon in the openned info pane, press `Command + c` to copy it.
  4. Open alacritty, and right click on the alacritty icon from the dock: Options --> Show in Finder
  5. Right click on alacritty icon from the finder: Get Info
  6. Click the left top icon in the openned info pane, press `Command + v` to paste the copied terminal
     icon to replace the default alacritty icon.
