# Completion for ghc-ghostty-shader

$ghcGhosttyShaderShaders = @(
    'off'
    'cubes'
    'fireworks-rockets'
    'gears-and-belts'
    'inside-the-matrix'
    'just-snow'
    'matrix-hallway'
    'mnoise'
    'sparks-from-fire'
    'starfield'
)

$ghcGhosttyShaderOpts = @('--silent', '--prev', '--next', '-s', '-p', '-n')

Register-ArgumentCompleter -CommandName ghc-ghostty-shader -ScriptBlock {
    param($commandName, $wordToComplete, $commandAst, $fakeBoundParameters)

    if ($wordToComplete -like '-*') {
        $ghcGhosttyShaderOpts | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    } else {
        $ghcGhosttyShaderShaders | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
