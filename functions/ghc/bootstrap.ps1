# Upgrade dev env.
function ghc-upgrade {
  pwsh "$env:XDG_CONFIG_HOME\guanghechen\win\setup.ps1"
}

function Script:Sync-GhcGitWorktrees {
  param(
    [string]$RepoRoot,
    [string]$RepoMain,
    [string]$RepoUrl,
    [string]$RepoName,
    [string]$Scope,
    [string[]]$Branches
  )

  if (-not (Test-Path -Path $RepoRoot)) {
    Write-Host ("   [{0}] mkdir -p {1}" -f $RepoName, $RepoRoot) -ForegroundColor Blue
    New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
    Write-Host
  }

  if ($Scope -eq "main") {
    $mainBranch = $Branches[0]
    $gitPath = Join-Path $RepoMain ".git"

    if (Test-Path $gitPath) {
      Write-Host "   [$RepoName] fetching and merging origin/$mainBranch" -ForegroundColor Blue
      git -C "$RepoMain" fetch origin
      git -C "$RepoMain" merge "origin/$mainBranch" --ff-only
      Write-Host
    } else {
      Write-Host "   [$RepoName] cloning $RepoUrl (branch: $mainBranch)" -ForegroundColor Blue
      git -C "$RepoRoot" clone $RepoUrl --branch=$mainBranch "$RepoMain"
      Write-Host
    }

    return
  }

  $isRequired = $Scope -eq "required"
  foreach ($branch in $Branches) {
    if ([string]::IsNullOrWhiteSpace($branch)) {
      continue
    }

    $repoPath = Join-Path $RepoRoot $branch

    if (Test-Path -Path $repoPath) {
      Write-Host "   [$RepoName] syncing $branch" -ForegroundColor Blue
      git -C "$repoPath" merge "origin/$branch" --ff-only
      Write-Host
    } elseif ($isRequired) {
      Write-Host "   [$RepoName] add new worktree of $branch" -ForegroundColor Blue
      git -C "$RepoMain" worktree add "$repoPath" $branch
      Write-Host
    }
  }
}

# Update config repositories.
function ghc-update {
  $configRoot = "$env:XDG_CONFIG_HOME"
  $configMain = Join-Path $configRoot "guanghechen"
  $configUrl = "https://github.com/guanghechen/config.git"
  $configMainBranch = "guanghechen"

  $configRequiredBranches = @("pwsh")
  $configOptionalBranches = @(
    "alacritty",
    "alacritty-windows",
    "bat",
    "btop",
    "claude",
    "codex",
    "conda",
    "cspell",
    "fzf",
    "gh",
    "ghostty",
    "git-delta",
    "helix",
    "kitty",
    "komorebi",
    "lazygit",
    "lsd",
    "neovide",
    "nvim",
    "nvim-lazy",
    "nvim-nvchad",
    "ora",
    "pm2",
    "ripgrep",
    "skhd",
    "tsuki",
    "wezterm",
    "yabai",
    "yasb",
    "yazi",
    "yoz"
  )

  Write-Host "  [$configMain] syncing..." -ForegroundColor Green
  Sync-GhcGitWorktrees -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "main" -Branches @($configMainBranch)
  Sync-GhcGitWorktrees -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "required" -Branches $configRequiredBranches
  Sync-GhcGitWorktrees -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "optional" -Branches $configOptionalBranches
  Write-Host "  [config] done." -ForegroundColor Cyan
  Write-Host

  #----------------------------------------------------------------------------------------------#

  $wikiRoot = Join-Path $HOME "wiki"
  $wikiMain = Join-Path $wikiRoot "wiki"
  $wikiUrl = "https://github.com/guanghechen/wiki.git"
  $wikiMainBranch = "wiki"

  $wikiRequiredBranches = @("translator", "wiki-note")
  $wikiOptionalBranches = @()

  Write-Host "  [$wikiMain] syncing..." -ForegroundColor Green
  Sync-GhcGitWorktrees -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "main" -Branches @($wikiMainBranch)
  Sync-GhcGitWorktrees -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "required" -Branches $wikiRequiredBranches
  Sync-GhcGitWorktrees -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "optional" -Branches $wikiOptionalBranches
  Write-Host "  [wiki] done." -ForegroundColor Cyan
}
