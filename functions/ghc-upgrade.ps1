# Upgrade dev env.
function ghc-upgrade {
  $configRoot = Join-Path $env:XDG_CONFIG_HOME "guanghechen"
  if ($env:GHC_CONFIG_ROOT) {
    $configRoot = $env:GHC_CONFIG_ROOT
  }

  $edition = ""
  if (Get-Command node -ErrorAction SilentlyContinue) {
    try {
      $edition = (node "$configRoot\src\setting.mjs" --print-edition 2>$null).Trim()
    } catch {
      $edition = ""
    }
  }

  if (-not $edition) {
    $edition = "win"
  }

  switch ($edition) {
    "nix" { bash "$configRoot/setup/nix/setup.sh"; break }
    "nix-remote" { bash "$configRoot/setup/nix-remote/setup.sh"; break }
    "osx" { bash "$configRoot/setup/osx/setup.sh"; break }
    "win" { pwsh "$configRoot\setup\win\setup.ps1"; break }
    default { pwsh "$configRoot\setup\win\setup.ps1"; break }
  }
}
