## Preferences #####################################################################################
if ([string]::IsNullOrWhiteSpace($env:ROOT_SOURCECODES)) { $env:ROOT_SOURCECODES = "C:\sourcecodes" }
if ([string]::IsNullOrWhiteSpace($env:ROOT_WORKSPACE)) { $env:ROOT_WORKSPACE = "C:\ws" }
if ([string]::IsNullOrWhiteSpace($env:YOZ_SERVER_PORT)) { $env:YOZ_SERVER_PORT = "7777" }

## Agent Environment ###############################################################################

$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:4747/api/claude"
$env:GOOGLE_GEMINI_BASE_URL = "http://127.0.0.1:4747/api/gemini"
$env:OPENAI_BASE_URL = "http://127.0.0.1:4747/api/codex"

$env:ANTHROPIC_MODEL = "claude-opus-4.8"
$env:ANTHROPIC_SMALL_FAST_MODEL = "claude-sonnet-4.6"
$env:CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

$env:GEMINI_MODEL = "gemini-3-pro-preview"

## App Environment #################################################################################
$env:f_windows_terminal_settings      = "${env:USERPROFILE}\AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$env:f_vscode_keybindings             = "${env:USERPROFILE}\AppData\Roaming\Code\User\keybindings.json"
$env:FZF_DEFAULT_COMMAND              = "fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f"
$env:FZF_DEFAULT_OPTS_FILE            = "$env:XDG_CONFIG_HOME\fzf\fzf.fzfrc"

## pnpm ############################################################################################
$pnpmHomeCandidates = @()
if ($env:LOCALAPPDATA) { $pnpmHomeCandidates += (Join-Path $env:LOCALAPPDATA "pnpm") }
if ($HOME) { $pnpmHomeCandidates += (Join-Path $HOME "Library/pnpm") }

$pnpmHome = $pnpmHomeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($pnpmHome) {
  $env:PNPM_HOME = $pnpmHome
  $pnpmBin = Join-Path $pnpmHome "bin"
  $pnpmPath = if (Test-Path $pnpmBin) { $pnpmBin } else { $pnpmHome }
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
