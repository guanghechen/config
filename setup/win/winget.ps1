param(
  [scriptblock]$InstallPackage = {
    param(
      [string]$Package
    )

    winget install -e --source winget --id "$Package"
  }
)

Write-Host "installing Windows packages..." -ForegroundColor Cyan

$noApplicableUpgradeExitCode = -1978335189

# Managed separately as setup prerequisites: Git.Git, Microsoft.PowerShell.
# Disabled: wez.wezterm, LLVM.LLVM, Gyan.FFmpeg, LGUG2Z.komorebi, AmN.yasb.
$packages = @(
  "Microsoft.WindowsTerminal.Preview"
  "Microsoft.PowerToys"
  "Neovim.Neovim"
  "GitHub.Copilot"

  "Schniz.fnm"
  "astral-sh.uv"
  "pnpm.pnpm"

  "ImageMagick.ImageMagick"
  "junegunn.fzf"
  "jqlang.jq"
  "JesseDuffield.lazygit"

  "sharkdp.bat"
  "dandavison.delta"
  "sharkdp.fd"
  "lsd-rs.lsd"
  "BurntSushi.ripgrep.MSVC"
  "Starship.Starship"
  "sxyazi.yazi"
  "ajeetdsouza.zoxide"

  "Cloudflare.cloudflared"
)

foreach ($package in $packages) {
  $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  try {
    # WinGet uses a non-zero status when an installed package has no available
    # upgrade, so inspect its exit code before promoting failures.
    $PSNativeCommandUseErrorActionPreference = $false
    & $InstallPackage $package
    $exitCode = $LASTEXITCODE
  } finally {
    $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
  }

  if ($exitCode -eq 0) {
    continue
  }
  if ($exitCode -eq $noApplicableUpgradeExitCode) {
    Write-Host "$package is already current (skipped)" -ForegroundColor Yellow
    $global:LASTEXITCODE = 0
    continue
  }
  throw "[setup winget] failed to install $package (exit code: $exitCode)."
}
