## Common Environment ##############################################################################
$env:GHC_ANTHROPIC_BASE_URL           = "http://${env:GHC_COPILOT_API_HOST}:${env:GHC_COPILOT_API_PORT}/api/claude"
$env:GHC_ANTHROPIC_AUTH_TOKEN         = "${env:GHC_COPILOT_AUTH_TOKEN}"
$env:GHC_CODEX_AUTH_TOKEN             = "${env:GHC_COPILOT_AUTH_TOKEN}"
$env:GHC_GEMINI_BASE_URL              = "http://${env:GHC_COPILOT_API_HOST}:${env:GHC_COPILOT_API_PORT}/api/gemini"
$env:GHC_GEMINI_AUTH_TOKEN            = "${env:GHC_COPILOT_AUTH_TOKEN}"

## Agent Environment ###############################################################################
$env:ANTHROPIC_BASE_URL               = "${env:GHC_ANTHROPIC_BASE_URL}"
$env:ANTHROPIC_AUTH_TOKEN             = "${env:GHC_ANTHROPIC_AUTH_TOKEN}"
$env:ANTHROPIC_MODEL                  = "claude-opus-4.6"
$env:ANTHROPIC_SMALL_FAST_MODEL       = "claude-sonnet-4.5"
$env:CLAUDE_CONFIG_DIR                = "${env:XDG_CONFIG_HOME}\claude"

$env:CODEX_HOME                       = "${env:XDG_CONFIG_HOME}\codex"

$env:GOOGLE_GEMINI_BASE_URL           = "${env:GHC_GEMINI_BASE_URL}"
$env:GEMINI_API_KEY                   = "${env:GHC_GEMINI_AUTH_TOKEN}"
$env:GEMINI_MODEL                     = "gemini-3-pro-preview"
$env:GEMINI_CONFIG_DIR                = "${env:USERPROFILE}\.gemini"

## App Environment #################################################################################
$env:f_windows_terminal_settings      = "${env:USERPROFILE}\AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$env:f_vscode_keybindings             = "${env:USERPROFILE}\AppData\Roaming\Code\User\keybindings.json"

## PowerShell Modules ##############################################################################
# Ensure custom modules directory exists and lives at the front of PSModulePath.
$moduleRoot = Join-Path $env:XDG_CONFIG_HOME "pwsh/modules"
if (-not (Test-Path $moduleRoot)) {
  New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
}

$pathSeparator = [System.IO.Path]::PathSeparator
$currentModulePaths = if ($env:PSModulePath) {
  $env:PSModulePath -split [System.IO.Path]::PathSeparator
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
