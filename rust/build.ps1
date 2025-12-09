param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = $PSScriptRoot
Set-Location $SCRIPT_DIR

# ANSI color codes
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[0;33m"
$BLUE = "`e[0;34m"
$CYAN = "`e[0;36m"
$RESET = "`e[0m"

# Function to build a Rust package and deploy it
# Parameters:
#   SourceName - original package name (e.g., yoz)
#   TargetName - target package name for output (e.g., yoz)
#   ForceRebuild - whether to force rebuild
function Invoke-GhcRustBuild {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceName,

        [Parameter(Mandatory=$true)]
        [string]$TargetName,

        [Parameter(Mandatory=$false)]
        [bool]$ForceRebuild = $false
    )

    Set-Location $SCRIPT_DIR

    if ([string]::IsNullOrEmpty($SourceName) -or [string]::IsNullOrEmpty($TargetName)) {
        Write-Host "${RED}[neovim ${SourceName}] error: missing required parameters${RESET}"
        return $false
    }

    $cargoTargetDir = Join-Path -Path $SCRIPT_DIR -ChildPath "target"
    $packageDir = Join-Path -Path $SCRIPT_DIR -ChildPath $SourceName

    if (-not (Test-Path -Path $packageDir -PathType Container)) {
        Write-Host "${RED}[neovim $SourceName] error: package not found${RESET}"
        return $false
    }

    Set-Location $packageDir

    $luaDir = Join-Path -Path $SCRIPT_DIR -ChildPath "../lua"
    $binDir = Join-Path -Path $SCRIPT_DIR -ChildPath "../bin"

    if (-not (Test-Path -Path $luaDir)) {
        New-Item -Path $luaDir -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -Path $binDir)) {
        New-Item -Path $binDir -ItemType Directory -Force | Out-Null
    }

    $luaOutput = Join-Path -Path $luaDir -ChildPath "${TargetName}.dll"
    $binOutput = Join-Path -Path $binDir -ChildPath "win.${TargetName}.dll"
    $libName = "${SourceName}.dll"

    if ($ForceRebuild -or (-not (Test-Path -Path $luaOutput))) {
        Write-Host "${CYAN}[neovim $SourceName] compiling...${RESET}"

        cargo build --release --quiet

        if ($LASTEXITCODE -ne 0) {
            Write-Host "${RED}[neovim $SourceName] error: compilation failed${RESET}"
            Set-Location $SCRIPT_DIR
            return $false
        }

        if (Test-Path -Path $luaOutput) {
            Remove-Item -Path $luaOutput -Force
        }
        if (Test-Path -Path $binOutput) {
            Remove-Item -Path $binOutput -Force
        }

        $sourceLib = Join-Path -Path $cargoTargetDir -ChildPath "release/$libName"
        Copy-Item -Path $sourceLib -Destination $luaOutput -Force
        Copy-Item -Path $sourceLib -Destination $binOutput -Force

        if (Test-Path -Path $cargoTargetDir) {
            Remove-Item -Path $cargoTargetDir -Recurse -Force
        }

        Write-Host "${GREEN}[neovim $SourceName] ✓ built${RESET}"
    } else {
        Write-Host "${GREEN}[neovim $SourceName] ✓ cached${RESET}"
    }

    return $true
}

# Build packages
Invoke-GhcRustBuild -SourceName "yoz" -TargetName "yoz" -ForceRebuild $Force.IsPresent

Write-Host "${BLUE}[neovim build] done${RESET}"
