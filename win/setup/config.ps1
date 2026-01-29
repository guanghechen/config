Write-Host "`n  [setup config] preparing..." -ForegroundColor Cyan

$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $reporoot guanghechen
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
  $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
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
  $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
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
. .\win\setup\nvim.ps1

# Setup rust
$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "  [setup config] cargo config already exists. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup config] copying cargo.toml..." -ForegroundColor Cyan
  $source = Join-Path $reporoot "guanghechen\config\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

# Setup newsboat platform symlink
$newsboat_config_dir = Join-Path $env:XDG_CONFIG_HOME "newsboat"
if (Test-Path $newsboat_config_dir) {
  $newsboat_platform_link = Join-Path $newsboat_config_dir "local\platform"
  $newsboat_platform_dir = Join-Path $newsboat_config_dir "conf\platform"
  $newsboat_local_dir = Join-Path $newsboat_config_dir "local"

  # Create local dir if not exists
  if (-not (Test-Path $newsboat_local_dir)) {
    New-Item -ItemType Directory -Path $newsboat_local_dir -Force | Out-Null
  }

  # Create/update symlink
  $newsboat_platform_source = Join-Path $newsboat_platform_dir "win"
  if (Test-Path $newsboat_platform_source) {
    Write-Host "  [setup config] setting up newsboat platform symlink (win)..." -ForegroundColor Cyan
    if (Test-Path $newsboat_platform_link) {
      Remove-Item $newsboat_platform_link -Force
    }
    New-Item -ItemType SymbolicLink -Path $newsboat_platform_link -Target $newsboat_platform_source -Force | Out-Null
  }
}

Write-Host "  [setup config] done." -ForegroundColor Green
