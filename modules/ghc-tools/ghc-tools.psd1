@{
    RootModule        = 'ghc-tools.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '61ac034a-f8b7-41a9-8941-7a5b80023375'
    Author            = 'guanghechen'
    CompanyName       = 'guanghechen'
    Copyright         = 'Copyright (c) guanghechen'
    PowerShellVersion = '7.0'
    Description       = 'Helper functions for Guanghechen config environment.'
    FunctionsToExport = @(
        'ghc-opensource'
        'ghc-proxy'
        'ghc-theme'
        'ghc-update-agents'
        'ghc-update'
        'ghc-upgrade'
        'ghc-winshark-vsc'
        'yoz'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{}
}
