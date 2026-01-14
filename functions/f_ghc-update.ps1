function __ghc_update_sync_worktrees__ {
  param(
    [string]$RepoRoot,
    [string]$RepoMain,
    [string]$RepoUrl,
    [string]$RepoName,
    [string]$Scope,
    [string[]]$Branches
  )

  if (-not (Test-Path -Path $RepoRoot)) {
    Write-Host ("  [{0}] mkdir -p {1}" -f $RepoName, $RepoRoot) -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
    Write-Host
  }

  if ($Scope -eq "main") {
    $mainBranch = $Branches[0]
    $gitPath = Join-Path $RepoMain ".git"

    if (Test-Path $gitPath) {
      Write-Host "  [$RepoName] fetching and merging origin/$mainBranch" -ForegroundColor Cyan
      git -C "$RepoMain" fetch origin
      git -C "$RepoMain" merge "origin/$mainBranch" --ff-only
      Write-Host
    } else {
      Write-Host "  [$RepoName] cloning $RepoUrl (branch: $mainBranch)" -ForegroundColor Cyan
      git -C "$RepoRoot" clone $RepoUrl --branch=$mainBranch "$RepoMain"
      Write-Host
    }

    return
  }

  $isRequired = $Scope -eq "required"
  foreach ($branchSpec in $Branches) {
    if ([string]::IsNullOrWhiteSpace($branchSpec)) {
      continue
    }

    # Parse branch spec: "branch" or "branch:target_dir" (e.g., "gemini:~/.gemini")
    $branchParts = $branchSpec -split ':', 2
    $branch = $branchParts[0]
    $targetDir = if ($branchParts.Length -gt 1) { $branchParts[1] } else { $null }

    if ($targetDir) {
      if ($targetDir -match '^[/~]') {
        $repoPath = $targetDir -replace '^~', $HOME
      } else {
        $repoPath = Join-Path $RepoRoot $targetDir
      }
    } else {
      $repoPath = Join-Path $RepoRoot $branch
    }

    if (Test-Path -Path $repoPath) {
      Write-Host "  [$RepoName] syncing $branch" -ForegroundColor Cyan
      git -C "$repoPath" merge "origin/$branch" --ff-only
      Write-Host
    } elseif ($isRequired) {
      Write-Host "  [$RepoName] add new worktree of $branch" -ForegroundColor Cyan
      git -C "$RepoMain" worktree add "$repoPath" $branch
      Write-Host
    }
  }
}

# Update config repositories.
function f_ghc-update {
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
    "gemini:~/.gemini",
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
    "opencode",
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

  Write-Host "  [$configMain] syncing..." -ForegroundColor Cyan
  __ghc_update_sync_worktrees__ -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "main" -Branches @($configMainBranch)
  __ghc_update_sync_worktrees__ -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "required" -Branches $configRequiredBranches
  __ghc_update_sync_worktrees__ -RepoRoot $configRoot -RepoMain $configMain -RepoUrl $configUrl -RepoName "config" -Scope "optional" -Branches $configOptionalBranches
  Write-Host "  [config] done." -ForegroundColor Green
  Write-Host

  #----------------------------------------------------------------------------------------------#

  $wikiRoot = Join-Path $HOME "wiki"
  $wikiMain = Join-Path $wikiRoot "wiki"
  $wikiUrl = "https://github.com/guanghechen/wiki.git"
  $wikiMainBranch = "wiki"

  $wikiRequiredBranches = @("translator", "wiki-note")
  $wikiOptionalBranches = @()

  Write-Host "  [$wikiMain] syncing..." -ForegroundColor Cyan
  __ghc_update_sync_worktrees__ -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "main" -Branches @($wikiMainBranch)
  __ghc_update_sync_worktrees__ -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "required" -Branches $wikiRequiredBranches
  __ghc_update_sync_worktrees__ -RepoRoot $wikiRoot -RepoMain $wikiMain -RepoUrl $wikiUrl -RepoName "wiki" -Scope "optional" -Branches $wikiOptionalBranches
  Write-Host "  [wiki] done." -ForegroundColor Green
}
