complete ghc-theme --no-files

# Subcommands
complete ghc-theme -n "__fish_use_subcommand" -a apply -d "Apply a theme"
complete ghc-theme -n "__fish_use_subcommand" -a gen -d "Generate theme files"
complete ghc-theme -n "__fish_use_subcommand" -a generate -d "Generate theme files"
complete ghc-theme -n "__fish_use_subcommand" -a toggle -d "Toggle theme"

# Global options
complete ghc-theme -s s -l silent -d "Suppress all output"
complete ghc-theme -s h -l help -d "Show help"

# Theme names for apply and toggle
complete ghc-theme -n "__fish_seen_subcommand_from apply toggle" -a "
    catppuccin-frappe
    catppuccin-latte
    catppuccin-macchiato
    catppuccin-mocha
    gruvbox-dark
    gruvbox-light
    nord
    onehalf-dark
    onehalf-light
    rosepine-dawn
    rosepine-main
    rosepine-moon
    tokyonight-day
    tokyonight-moon
    tokyonight-night
    tokyonight-storm
    vsc-dark-modern
    vsc-light-modern
"
