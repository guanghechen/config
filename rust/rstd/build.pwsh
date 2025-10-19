param(
    [Alias("f")]
    [switch]$Force
)

Set-Location -Path $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($env:CARGO_TARGET_DIR)) {
    $targetDir = Join-Path -Path $PSScriptRoot -ChildPath "target"
} elseif ([System.IO.Path]::IsPathRooted($env:CARGO_TARGET_DIR)) {
    $targetDir = $env:CARGO_TARGET_DIR
} else {
    $targetDir = Join-Path -Path $PSScriptRoot -ChildPath $env:CARGO_TARGET_DIR
}

$releaseDir = Join-Path -Path $targetDir -ChildPath "release"
$buildOutputPath = Join-Path -Path $releaseDir -ChildPath "rstd.dll"

$luaTargetPath = Join-Path -Path $PSScriptRoot -ChildPath "../../lua/rstd.dll"
$binTargetPath = Join-Path -Path $PSScriptRoot -ChildPath "../../bin/win.rstd.dll"
$binDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath "../../bin"

if ($Force -or (-not (Test-Path -Path $luaTargetPath))) {
    cargo build --release

    if (Test-Path -Path $luaTargetPath) {
        Remove-Item -Path $luaTargetPath -Force
    }
    if (Test-Path -Path $binTargetPath) {
        Remove-Item -Path $binTargetPath -Force
    }
    if (-not (Test-Path -Path $binDirectoryPath)) {
        New-Item -Path $binDirectoryPath -ItemType Directory | Out-Null
    }

    Copy-Item -Path $buildOutputPath -Destination $luaTargetPath
    Copy-Item -Path $buildOutputPath -Destination $binTargetPath
}

Write-Output "Build Done"
