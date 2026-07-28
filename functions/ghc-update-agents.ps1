# Update AI coding agents globally
function ghc-update-agents {
  [CmdletBinding()]
  param(
    [switch] $SkipInstallation
  )

  $agents = @(
    "@anthropic-ai/claude-code"
    "@google/gemini-cli"
    "@openai/codex"
    "@github/copilot"
    "opencode-ai"
  )

  if (-not $SkipInstallation) {
    foreach ($agent in $agents) {
      Write-Host "  Installing $agent..." -ForegroundColor Cyan
      npm install -g $agent | Out-Null
      $pkg_ver = (npm list -g $agent --depth=0 2>$null | Select-String $agent) -replace '.*@', ''
      Write-Host "  $agent installed: v$pkg_ver`n" -ForegroundColor Green
    }
  }
  else {
    Write-Host "  Skipping agent installation as requested`n" -ForegroundColor Yellow
  }

  if (Get-Command claude -ErrorAction SilentlyContinue) {
    $xdgConfigHome = if ($env:XDG_CONFIG_HOME) {
      $env:XDG_CONFIG_HOME
    } elseif ($env:USERPROFILE) {
      Join-Path $env:USERPROFILE ".config"
    } else {
      Join-Path $HOME ".config"
    }

    Write-Host "  Patching Claude Code..." -ForegroundColor Cyan
    $patchScript = Join-Path $xdgConfigHome "guanghechen" "cli" "patch-agents.mjs"
    Write-Host "  node $patchScript --agent claude" -ForegroundColor Cyan
    node $patchScript --agent claude

    $claudeSettingsDir = Join-Path $xdgConfigHome "claude"
    $claudeSettingsFile = Join-Path $claudeSettingsDir "settings.json"
    if (Test-Path $claudeSettingsFile) {
      try {
        $settingsJson = Get-Content $claudeSettingsFile -Raw | ConvertFrom-Json
      }
      catch {
        $settingsJson = $null
      }
      $excludedPlugins = @(
        "ralph-loop@claude-plugins-official"
      )
      $enabledPlugins = @()
      if ($settingsJson -and $settingsJson.enabledPlugins) {
        foreach ($entry in $settingsJson.enabledPlugins.PSObject.Properties) {
          if ($entry.Value -is [bool] -and $entry.Value -and $entry.Name -notin $excludedPlugins) {
            $enabledPlugins += $entry.Name
          }
        }
      }

      if ($enabledPlugins.Count -gt 0) {
        Write-Host "  Syncing Claude Code plugins..." -ForegroundColor Cyan
        claude plugin marketplace update
        foreach ($plugin in $enabledPlugins) {
          Write-Host "  Installing $plugin..." -ForegroundColor DarkGray
          claude plugin install $plugin --scope user | Out-Null
        }
        Write-Host ("  Synced {0} plugin(s)`n" -f $enabledPlugins.Count) -ForegroundColor Green
      }
    }
  }
}
