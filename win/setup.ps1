$env:APP_HOME_MINIFORGE   = "C:\app\miniforge"
$env:APP_HOME_GIT         = "C:\app\git"
$env:XDG_CONFIG_HOME      = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME        = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME       = "$env:USERPROFILE\.local\state"
$env:CLAUDE_CONFIG_DIR    = "$env:XDG_CONFIG_HOME\claude"
$env:CODEX_HOME           = "$env:XDG_CONFIG_HOME\codex"
$env:GEMINI_CONFIG_DIR    = "$env:USERPROFILE\.gemini"
$env:KOMOREBI_CONFIG_HOME = "$env:XDG_CONFIG_HOME\komorebi"
$env:LG_CONFIG_FILE       = "$env:XDG_CONFIG_HOME\lazygit\config.yml,$env:XDG_CONFIG_HOME\lazygit\local\theme.yml"
$env:LS_COLORS            = "di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93"
$env:NODE_OPTIONS         = "--max-old-space-size=8192"
$env:PYTHONIOENCODING     = "utf8"
$env:PYTHONUTF8           = 1
$env:YAZI_CONFIG_HOME     = "$env:XDG_CONFIG_HOME\yazi"
$env:YAZI_FILE_ONE        = "$env:APP_HOME_GIT\usr\bin\file.exe"
$env:PREFER_NODE_VERSION  = 25
$env:PREFER_PYTHON_ENV    = "lemon"

setx APP_HOME_MINIFORGE   "$env:APP_HOME_MINIFORGE"
setx APP_HOME_GIT         "$env:APP_HOME_GIT"
setx XDG_CONFIG_HOME      "$env:XDG_CONFIG_HOME"
setx XDG_DATA_HOME        "$env:XDG_DATA_HOME"
setx XDG_STATE_HOME       "$env:XDG_STATE_HOME"
setx CLAUDE_CONFIG_DIR    "$env:CLAUDE_CONFIG_DIR"
setx CODEX_HOME           "$env:CODEX_HOME"
setx GEMINI_CONFIG_DIR    "$env:GEMINI_CONFIG_DIR"
setx KOMOREBI_CONFIG_HOME "$env:KOMOREBI_CONFIG_HOME"
setx LG_CONFIG_FILE       "$env:LG_CONFIG_FILE"
setx LS_COLORS            "$env:LS_COLORS"
setx NODE_OPTIONS         "$env:NODE_OPTIONS"
setx PYTHONIOENCODING     "$env:PYTHONIOENCODING"
setx PYTHONUTF8           $env:PYTHONUTF8
setx YAZI_CONFIG_HOME     "$env:YAZI_CONFIG_HOME"
setx YAZI_FILE_ONE        "$env:YAZI_FILE_ONE"
setx PREFER_NODE_VERSION  $env:PREFER_NODE_VERSION
setx PREFER_PYTHON_ENV    "$env:PREFER_PYTHON_ENV"

# Define the local path and repositories
$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $reporoot "guanghechen"
if (Test-Path $repomain) {
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
} else {
  New-Item -ItemType Directory -Path "$reporoot" -Force | Out-Null
  git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
}

Set-Location -Path $repomain
. .\win\setup\cargo.ps1

Set-Location -Path $repomain
. .\win\setup\winget.ps1

Set-Location -Path $repomain
. .\win\setup\config.ps1

Set-Location -Path $repomain
. .\win\setup\node.ps1

Set-Location -Path $repomain
. .\win\setup\miniforge.ps1

Set-Location -Path $repomain
. .\win\setup\theme.ps1

