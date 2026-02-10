$modulesRoot = Split-Path -Parent $PSScriptRoot
$pwshRoot = Split-Path -Parent $modulesRoot
$functionsRoot = Join-Path $pwshRoot "functions"

$lazyFunctions = @(
    'ghc-claude-remote'
    'ghc-opensource'
    'ghc-proxy'
    'ghc-theme'
    'ghc-update-agents'
    'ghc-update'
    'ghc-upgrade'
    'swap-alt-win'
    'yoz'
)

foreach ($name in $lazyFunctions) {
    $scriptPath = Join-Path $functionsRoot "$name.ps1"
    $sb = [scriptblock]::Create(@"
        . '$scriptPath'
        & $name @args
"@)
    Set-Item -Path "function:$name" -Value $sb
}

Export-ModuleMember -Function $lazyFunctions
