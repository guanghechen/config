# Completion for ghc-theme

$ghcThemeSubcmds = @('apply', 'gen', 'generate', 'toggle')

$ghcThemeThemes = @(
    'catppuccin-frappe'
    'catppuccin-latte'
    'catppuccin-macchiato'
    'catppuccin-mocha'
    'gruvbox-dark'
    'gruvbox-light'
    'nord'
    'onehalf-dark'
    'onehalf-light'
    'rosepine-dawn'
    'rosepine-main'
    'rosepine-moon'
    'tokyonight-day'
    'tokyonight-moon'
    'tokyonight-night'
    'tokyonight-storm'
    'vsc-dark-modern'
    'vsc-light-modern'
)

$ghcThemeOpts = @('--silent', '-s', '--help', '-h')

Register-ArgumentCompleter -CommandName ghc-theme -ScriptBlock {
    param($commandName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $tokens = $commandAst.CommandElements | ForEach-Object { $_.Extent.Text }

    # Determine position and previous token
    $prevToken = if ($tokens.Count -gt 1) { $tokens[-2] } else { $null }

    if ($tokens.Count -eq 1 -or ($tokens.Count -eq 2 -and $wordToComplete)) {
        # Complete subcommand or option
        $candidates = $ghcThemeSubcmds + $ghcThemeOpts
        $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    } elseif ($prevToken -in @('apply', 'toggle')) {
        # Complete theme name
        $ghcThemeThemes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    } elseif ($wordToComplete -like '-*') {
        # Complete option
        $ghcThemeOpts | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
