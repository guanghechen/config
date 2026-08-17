function Get-CargoPath {
  param([string]$Value, [string]$LocalBin, [string]$CargoBin)

  $localKey = $LocalBin.TrimEnd('\').ToLowerInvariant()
  $cargoKey = $CargoBin.TrimEnd('\').ToLowerInvariant()
  $result = @()
  $foundCargo = $false

  foreach ($entry in ($Value -split ';')) {
    $entry = $entry.Trim()
    if ([string]::IsNullOrWhiteSpace($entry)) {
      continue
    }
    $key = [Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\').ToLowerInvariant()
    if ($key -eq $localKey) {
      continue
    }
    if ($key -eq $cargoKey) {
      if (-not $foundCargo) {
        $result += $LocalBin, $entry
        $foundCargo = $true
      }
      continue
    }
    $result += $entry
  }

  if (-not $foundCargo) {
    $result += $LocalBin, $CargoBin
  }
  return ($result -join ';')
}

$cargoHome = if ([string]::IsNullOrWhiteSpace($env:CARGO_HOME)) {
  Join-Path $env:USERPROFILE ".cargo"
} else {
  $env:CARGO_HOME
}
if (-not [IO.Path]::IsPathRooted($cargoHome)) {
  throw "[setup kit-repo] CARGO_HOME must be absolute: $cargoHome"
}

$cargoBin = Join-Path $cargoHome "bin"
$cargoLocalBin = Join-Path $cargoHome "local\bin"
$installedBinary = Join-Path $cargoBin "kit-repo.exe"

$installedItem = Get-Item -LiteralPath $installedBinary -Force -ErrorAction SilentlyContinue
if ($null -ne $installedItem -and ($installedItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  throw "[setup kit-repo] legacy development link found at $installedBinary. Run: `$env:BIN_DIR='$cargoBin'; cargo unlink"
}

Write-Host "`n  [setup kit-repo] installing the latest published version..." -ForegroundColor Cyan
cargo install --locked --root "$cargoHome" guanghechen-kit-repo
if ($LASTEXITCODE -ne 0) {
  throw "[setup kit-repo] cargo install failed (exit code: $LASTEXITCODE)."
}
if (-not (Test-Path -LiteralPath $installedBinary -PathType Leaf)) {
  throw "[setup kit-repo] cargo completed without installing $installedBinary."
}

New-Item -ItemType Directory -Path $cargoLocalBin -Force -ErrorAction Stop | Out-Null
$env:Path = Get-CargoPath -Value $env:Path -LocalBin $cargoLocalBin -CargoBin $cargoBin

$userEnvironment = Get-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Environment" -ErrorAction Stop
try {
  $hasUserPath = $userEnvironment.GetValueNames() -contains "Path"
  $userPath = [string]$userEnvironment.GetValue(
    "Path",
    "",
    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
  )
  $userPathKind = if ($hasUserPath) {
    $userEnvironment.GetValueKind("Path")
  } else {
    [Microsoft.Win32.RegistryValueKind]::String
  }
  $nextUserPath = Get-CargoPath -Value $userPath -LocalBin $cargoLocalBin -CargoBin $cargoBin

  if (-not [string]::Equals($userPath, $nextUserPath, [StringComparison]::Ordinal)) {
    $userEnvironment.SetValue("Path", $nextUserPath, $userPathKind)
    $verifiedUserPath = [string]$userEnvironment.GetValue(
      "Path",
      "",
      [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    )
    if (-not [string]::Equals($verifiedUserPath, $nextUserPath, [StringComparison]::Ordinal)) {
      throw "[setup kit-repo] failed to verify the updated User PATH."
    }
  }
} finally {
  $userEnvironment.Close()
}
