# Upgrade dev env.
function ghc-upgrade {
  pwsh "$env:XDG_CONFIG_HOME\guanghechen\win\setup.ps1"
}

# Update config repositories.
function ghc-update {
  $reporoot = "$env:XDG_CONFIG_HOME"
  $repomain = Join-Path $reporoot "guanghechen"

  if (Test-Path $repomain) {
    git -C "$repomain" fetch origin
    git -C "$repomain" merge origin/guanghechen --ff-only
  } else {
    git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
  }

  $repo_required_branches = @(
    "bat",
    "conda",
    "gh",
    "git-delta",
    "fzf",
    "lazygit",
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
    "fish",
    "ghostty",
    "helix",
    "kitty",
    "komorebi",
    "lsd",
    "neovide",
    "nvim-lazy",
    "nvim-nvchad",
    "plan",
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
      Write-Host "merging origin/$branch into $repopath..." -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
    } else {
      Write-Host "add new worktree of $branch into $repopath..." -ForegroundColor DarkBlue
      $cmd = "git -C '$repomain' worktree add '$repopath' $branch"
    }
    Invoke-Expression $cmd
    Write-Host
  }

  foreach ($branch in $repo_optional_branches) {
    $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
    if (Test-Path -Path $repopath) {
      Write-Host "merging origin/$branch into $repopath..." -ForegroundColor DarkBlue
      $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
      Invoke-Expression $cmd
      Write-Host
    }
  }
}

