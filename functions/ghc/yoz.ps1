function yoz {
    <#
    .SYNOPSIS
    Preview file with yozora
    .PARAMETER filepath
    The file path to preview
    .PARAMETER force
    Force flag for yozora
    #>
    param(
        [Parameter(Position = 0)]
        [string]$filepath,

        [switch]$force
    )

    if (-not $filepath) {
        Write-Host "Usage: yoz <filepath> [-force]"
        return 1
    }

    if (-not $env:YOZORA_SERVER_PORT) {
        Write-Host "Error: YOZORA_SERVER_PORT not set"
        return 1
    }

    $resolvedPath = Resolve-Path $filepath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Host "Error: File not found: $filepath"
        return 1
    }

    $encodedPath = [System.Web.HttpUtility]::UrlEncode($resolvedPath.Path)
    $forceValue = if ($force) { "true" } else { "false" }
    $url = "http://localhost:$env:YOZORA_SERVER_PORT/api/file-switch?filepath=$encodedPath&force=$forceValue"

    Start-Job -ScriptBlock {
        param($url)
        try {
            Invoke-RestMethod -Uri $url -Method POST -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Silently ignore errors
        }
    } -ArgumentList $url | Out-Null
}
