# Completion for ghc-update-agents

Register-ArgumentCompleter -CommandName ghc-update-agents -ScriptBlock {
    param($commandName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $opts = @('-SkipInstallation')

    $opts | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
