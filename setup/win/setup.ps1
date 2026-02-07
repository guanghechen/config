$env:APP_HOME_MINIFORGE   = "C:\app\miniforge"
$env:APP_HOME_GIT         = "C:\app\git"
$env:XDG_CONFIG_HOME      = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME        = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME       = "$env:USERPROFILE\.local\state"
$env:KOMOREBI_CONFIG_HOME = "$env:XDG_CONFIG_HOME\komorebi"
$env:LG_CONFIG_FILE       = "$env:XDG_CONFIG_HOME\lazygit\config.yml,$env:XDG_CONFIG_HOME\lazygit\local\theme.yml"
$env:LIBCLANG_PATH        = "C:\Program Files\LLVM\bin"
$env:LS_COLORS            = "di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93"
$env:NODE_OPTIONS         = "--max-old-space-size=8192"
$env:PYTHONIOENCODING     = "utf8"
$env:PYTHONUTF8           = 1
$env:YAZI_CONFIG_HOME     = "$env:XDG_CONFIG_HOME\yazi"
$env:YAZI_FILE_ONE        = "$env:APP_HOME_GIT\usr\bin\file.exe"
$env:PREFER_NODE_VERSION  = if ($env:PREFER_NODE_VERSION) { $env:PREFER_NODE_VERSION } else {
  try { node "$env:XDG_CONFIG_HOME\guanghechen\cli\setting.mjs" --print-node-edition 2>$null } catch { 24 }
}
$env:PREFER_PYTHON_ENV    = "lemon"

setx APP_HOME_MINIFORGE   "$env:APP_HOME_MINIFORGE"
setx APP_HOME_GIT         "$env:APP_HOME_GIT"
setx XDG_CONFIG_HOME      "$env:XDG_CONFIG_HOME"
setx XDG_DATA_HOME        "$env:XDG_DATA_HOME"
setx XDG_STATE_HOME       "$env:XDG_STATE_HOME"
setx KOMOREBI_CONFIG_HOME "$env:KOMOREBI_CONFIG_HOME"
setx LG_CONFIG_FILE       "$env:LG_CONFIG_FILE"
setx LIBCLANG_PATH        "$env:LIBCLANG_PATH"
setx LS_COLORS            "$env:LS_COLORS"
setx NODE_OPTIONS         "$env:NODE_OPTIONS"
setx PYTHONIOENCODING     "$env:PYTHONIOENCODING"
setx PYTHONUTF8           $env:PYTHONUTF8
setx YAZI_CONFIG_HOME     "$env:YAZI_CONFIG_HOME"
setx YAZI_FILE_ONE        "$env:YAZI_FILE_ONE"
setx PREFER_NODE_VERSION  $env:PREFER_NODE_VERSION
setx PREFER_PYTHON_ENV    "$env:PREFER_PYTHON_ENV"

## Agent Environment ###############################################################################
$env:ANTHROPIC_BASE_URL               = "$GHC_ANTHROPIC_BASE_URL"
$env:ANTHROPIC_AUTH_TOKEN             = "$GHC_ANTHROPIC_AUTH_TOKEN"
$env:ANTHROPIC_MODEL                  = "claude-opus-4.5"
$env:ANTHROPIC_SMALL_FAST_MODEL       = "claude-sonnet-4.5"
$env:CLAUDE_CONFIG_DIR                = "$XDG_CONFIG_HOME/claude"
$env:CODEX_HOME                       = "$XDG_CONFIG_HOME/codex"
$env:GOOGLE_GEMINI_BASE_URL           = "$GHC_GEMINI_BASE_URL"
$env:GEMINI_API_KEY                   = "$GHC_GEMINI_AUTH_TOKEN"
$env:GEMINI_MODEL                     = "gemini-3-pro-preview"
$env:GEMINI_CONFIG_DIR                = "$HOME/.gemini"

setx ANTHROPIC_BASE_URL               "$env:ANTHROPIC_BASE_URL"
setx ANTHROPIC_AUTH_TOKEN             "$env:ANTHROPIC_AUTH_TOKEN"
setx ANTHROPIC_MODEL                  "$env:ANTHROPIC_MODEL"
setx ANTHROPIC_SMALL_FAST_MODEL       "$env:ANTHROPIC_SMALL_FAST_MODEL"
setx CLAUDE_CONFIG_DIR                "$env:CLAUDE_CONFIG_DIR"
setx CODEX_HOME                       "$env:CODEX_HOME"
setx GOOGLE_GEMINI_BASE_URL           "$env:GOOGLE_GEMINI_BASE_URL"
setx GEMINI_API_KEY                   "$env:GEMINI_API_KEY"
setx GEMINI_MODEL                     "$env:GEMINI_MODEL"
setx GEMINI_CONFIG_DIR                "$env:GEMINI_CONFIG_DIR"

####################################################################################################

## Conditional Environment ##########################################################################
if (Test-Path "$env:APP_HOME_GIT\bin\bash.exe") {
  $env:CLAUDE_CODE_GIT_BASH_PATH = "$env:APP_HOME_GIT\bin\bash.exe"
  setx CLAUDE_CODE_GIT_BASH_PATH "$env:CLAUDE_CODE_GIT_BASH_PATH"
}
####################################################################################################


# Define the local path and repositories
$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $env:USERPROFILE ".config\guanghechen"
if (Test-Path $repomain) {
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
} else {
  New-Item -ItemType Directory -Path "$reporoot" -Force | Out-Null
  git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
}

Set-Location -Path $repomain
. .\setup\win\winget.ps1

Set-Location -Path $repomain
. .\setup\win\config.ps1

Set-Location -Path $repomain
. .\setup\win\env\cargo.ps1

Set-Location -Path $repomain
. .\setup\win\env\miniforge.ps1

Set-Location -Path $repomain
. .\setup\win\env\bun.ps1

Set-Location -Path $repomain
. .\setup\win\env\node.ps1

Set-Location -Path $repomain
. .\setup\win\env\pnpm.ps1

####################################################################################################

Set-Location -Path $repomain
. .\setup\win\app\newsboat.ps1

Set-Location -Path $repomain
. .\setup\win\app\nvim.ps1

Set-Location -Path $repomain
. .\setup\win\theme.ps1

Write-Host "`n ===== [setup settings] =====" -ForegroundColor Magenta
Write-Host "`n  [setup settings] preparing..." -ForegroundColor Cyan
Write-Host "  [setup settings] done." -ForegroundColor Green
