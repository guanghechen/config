Write-Host "`n  [setup config] preparing..." -ForegroundColor Cyan

if (-not $env:GHC_CONFIG_ROOT) {
  $env:GHC_CONFIG_ROOT = Join-Path $env:XDG_CONFIG_HOME "guanghechen"
}
$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = $env:GHC_CONFIG_ROOT
$repo_required_branches = @(
  "bat",
  "conda",
  "cspell",
  "gh",
  "git-delta",
  "fzf",
  "lazygit",
  "lsd",
  "nvim",
  "pwsh",
  "ripgrep",
  "yazi"
)
$repo_optional_branches = @(
  "alacritty",
  "alacritty-windows",
  "btop",
  "claude",
  "codex",
  "fish",
  "ghostty",
  "helix",
  "kitty",
  "kit-pm",
  "komorebi",
  "neovide",
  "newsboat",
  "nvim-lazy",
  "nvim-nvchad",
  "opencode",
  "ora",
  "pm2",
  "skhd",
  "tsuki",
  "wezterm",
  "yabai",
  "yasb",
  "yoz"
)

foreach ($branch in $repo_required_branches) {
  $repopath = Join-Path $reporoot $branch
  if (Test-Path -Path $repopath) {
    Write-Host "  [setup config] merging origin/$branch into $repopath..." -ForegroundColor Cyan
    $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
  } else {
    Write-Host "  [setup config] add new worktree of $branch into $repopath..." -ForegroundColor Cyan
    $cmd = "git -C '$repomain' worktree add '$repopath' $branch"
  }
  Invoke-Expression $cmd
}

foreach ($branch in $repo_optional_branches) {
  $repopath = Join-Path $reporoot $branch
  if (Test-Path -Path $repopath) {
    Write-Host "  [setup config] merging origin/$branch into $repopath..." -ForegroundColor Cyan
    $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
    Invoke-Expression $cmd
  }
}

# Define the source and destination paths
Write-Host "  [setup config] copying pwsh profile.ps1..." -ForegroundColor Cyan
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
Copy-Item -Path $source -Destination $PROFILE -Force

# Setup nvim
Write-Host "  [setup config] setup nvim..." -ForegroundColor Cyan
Set-Location -Path $repomain
. .\win\setup\app\nvim.ps1

# Setup rust
$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "  [setup config] cargo config already exists. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup config] copying cargo.toml..." -ForegroundColor Cyan
  $source = Join-Path $env:GHC_CONFIG_ROOT "asset\conf\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

Write-Host "  [setup config] done." -ForegroundColor Green
