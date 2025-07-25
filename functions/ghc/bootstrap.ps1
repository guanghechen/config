# Upgrade dev env.
function ghc-upgrade {
  pwsh "$env:XDG_CONFIG_HOME\guanghechen\win\setup.ps1"
}

# Update config repositories.
function ghc-update {
  $required_configs = @(
    "conda",
    "fzf",
    'guanghechen',
    "lazygit",
    "nvim",
    "pwsh",
    "ripgrep",
    "yazi"
  )
  $optional_configs = @(
    "alacritty",
    "alacritty-windows",
    "btop",
    "claude",
    "fish",
    "ghostty",
    "helix",
    "kitty",
    "lsd",
    "neovide",
    "nvim-nvchad",
    "opencode",
    "plan",
    "pm2",
    "tsuki",
    "wezterm",
    "yozora"
  )

  foreach ($branch in $required_configs) {
    $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
    if (Test-Path -Path $repopath) {
      Write-Host "fetching $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' pull origin $branch"
    } else {
      Write-Host "cloning $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git clone https://github.com/guanghechen/config.git --single-branch --branch=$branch '$repopath'"
    }
    Invoke-Expression $cmd
    Write-Host
  }

  foreach ($branch in $optional_configs) {
    $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
    if (Test-Path -Path $repopath) {
      Write-Host "fetching $branch into $repopath" -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' pull origin $branch"
      Invoke-Expression $cmd
      Write-Host
    }
  }
}

