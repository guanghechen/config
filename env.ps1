## Agents ##########################################################################################
$env:ANTHROPIC_BASE_URL     = "$env:KIT_COPILOT_URL/api/claude"
$env:GOOGLE_GEMINI_BASE_URL = "$env:KIT_COPILOT_URL/api/gemini"
$env:OPENAI_BASE_URL        = "$env:KIT_COPILOT_URL/api/codex"

## App Environment #################################################################################
# Model IDs and FZF_* remain owned by setup/win/setup.ps1 via setx.
$env:f_windows_terminal_settings = "${env:USERPROFILE}\AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$env:f_vscode_keybindings        = "${env:USERPROFILE}\AppData\Roaming\Code\User\keybindings.json"

## pnpm ############################################################################################
if (-not ($env:PNPM_HOME -and (Test-Path $env:PNPM_HOME))) {
  $pnpmHomeCandidates = @()
  if ($env:LOCALAPPDATA) { $pnpmHomeCandidates += (Join-Path $env:LOCALAPPDATA "pnpm") }
  if ($HOME) { $pnpmHomeCandidates += (Join-Path $HOME "Library/pnpm") }

  $pnpmHome = $pnpmHomeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($pnpmHome) { $env:PNPM_HOME = $pnpmHome }
}

if ($env:PNPM_HOME -and (Test-Path $env:PNPM_HOME)) {
  $pnpmBin = Join-Path $env:PNPM_HOME "bin"
  $pnpmPath = if (Test-Path $pnpmBin) { $pnpmBin } else { $env:PNPM_HOME }
  $appPathSeparator = [System.IO.Path]::PathSeparator
  $currentAppPaths = if ($env:PATH) {
    $env:PATH -split [Regex]::Escape([string]$appPathSeparator)
  } else {
    @()
  }

  if ($currentAppPaths -notcontains $pnpmPath) {
    $env:PATH = "$pnpmPath$appPathSeparator$env:PATH"
  }
}

## PowerShell Modules ##############################################################################

$moduleRoot = Join-Path $env:XDG_CONFIG_HOME "pwsh/modules"
if (-not (Test-Path $moduleRoot)) {
  New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
}

$pathSeparator = [System.IO.Path]::PathSeparator
$currentModulePaths = if ($env:PSModulePath) {
  $env:PSModulePath -split [Regex]::Escape([string]$pathSeparator)
} else {
  @()
}

if ($currentModulePaths -notcontains $moduleRoot) {
  if ($env:PSModulePath) {
    $env:PSModulePath = "$moduleRoot$pathSeparator$env:PSModulePath"
  } else {
    $env:PSModulePath = $moduleRoot
  }
}
