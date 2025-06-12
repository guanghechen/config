param(
    [switch]$Force
)

Set-Location -Path $PSScriptRoot

$luaTargetPath = Join-Path -Path $PSScriptRoot -ChildPath "../../lua/nvim_tools.dll"
$binTargetPath = Join-Path -Path $PSScriptRoot -ChildPath "../../bin/win.nvim_tools.dll"

if ($Force -or (-not (Test-Path -Path $luaTargetPath))) {
    cargo build --release

    if (Test-Path -Path $luaTargetPath) {
        Remove-Item -Path $luaTargetPath -Force
    }
    if (Test-Path -Path $binTargetPath) {
        Remove-Item -Path $binTargetPath -Force
    }

    $binDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath "../../bin"
    if (-not (Test-Path -Path $binDirectoryPath)) {
        New-Item -Path $binDirectoryPath -ItemType Directory | Out-Null
    }

    Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "target/release/nvim_tools.dll") -Destination $luaTargetPath
    Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "target/release/nvim_tools.dll") -Destination $binTargetPath
}

