if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
  throw "[setup preparation] required command not found: git"
}

if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
  throw "[setup preparation] required command not found: winget"
}

if (-not (Get-Command cargo -CommandType Application -ErrorAction SilentlyContinue)) {
  throw "[setup preparation] required command not found: cargo"
}

if (-not (Get-Command rustc -CommandType Application -ErrorAction SilentlyContinue)) {
  throw "[setup preparation] required command not found: rustc"
}

$env:APP_HOME_MINIFORGE    = "C:\app\miniforge"
$env:APP_HOME_GIT          = "C:\app\git"
$env:XDG_CONFIG_HOME       = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME         = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME        = "$env:USERPROFILE\.local\state"
$env:BUN_INSTALL           = "$env:USERPROFILE\.bun"
$env:CONDARC               = "$env:XDG_CONFIG_HOME\conda\condarc"
$env:CONDA_CHANGEPS1       = "false"
$env:EDITOR                = "nvim"
$env:FZF_DEFAULT_COMMAND   = "fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f"
$env:FZF_DEFAULT_OPTS_FILE = "$env:XDG_CONFIG_HOME\fzf\fzf.fzfrc"
$env:KOMOREBI_CONFIG_HOME  = "$env:XDG_CONFIG_HOME\komorebi"
$env:LG_CONFIG_FILE        = "$env:XDG_CONFIG_HOME\lazygit\config.yml,$env:XDG_CONFIG_HOME\lazygit\local\theme.yml"
$env:LS_COLORS             = "di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93"
$env:NODE_OPTIONS          = "--max-old-space-size=8192"
$env:no_proxy              = "localhost,127.0.0.1,::1"
$env:PYTHONIOENCODING      = "utf8"
$env:PYTHONPYCACHEPREFIX   = "$env:USERPROFILE\.cache\pycache"
$env:PYTHONUTF8            = 1
$env:ROOT_SOURCECODES      = "C:\sourcecodes"
$env:ROOT_WORKSPACE        = "C:\ws"
$env:VISUAL                = "nvim"
$env:YAZI_CONFIG_HOME      = "$env:XDG_CONFIG_HOME\yazi"
$env:YAZI_FILE_ONE         = "$env:APP_HOME_GIT\usr\bin\file.exe"
$env:YOZ_SERVER_PORT       = "7777"

setx APP_HOME_MINIFORGE    "$env:APP_HOME_MINIFORGE"
setx APP_HOME_GIT          "$env:APP_HOME_GIT"
setx XDG_CONFIG_HOME       "$env:XDG_CONFIG_HOME"
setx XDG_DATA_HOME         "$env:XDG_DATA_HOME"
setx XDG_STATE_HOME        "$env:XDG_STATE_HOME"
setx BUN_INSTALL           "$env:BUN_INSTALL"
setx CONDARC               "$env:CONDARC"
setx CONDA_CHANGEPS1       "$env:CONDA_CHANGEPS1"
setx EDITOR                "$env:EDITOR"
setx FZF_DEFAULT_COMMAND   "$env:FZF_DEFAULT_COMMAND"
setx FZF_DEFAULT_OPTS_FILE "$env:FZF_DEFAULT_OPTS_FILE"
setx KOMOREBI_CONFIG_HOME  "$env:KOMOREBI_CONFIG_HOME"
setx LG_CONFIG_FILE        "$env:LG_CONFIG_FILE"
setx LS_COLORS             "$env:LS_COLORS"
setx NODE_OPTIONS          "$env:NODE_OPTIONS"
setx no_proxy              "$env:no_proxy"
setx PYTHONIOENCODING      "$env:PYTHONIOENCODING"
setx PYTHONPYCACHEPREFIX   "$env:PYTHONPYCACHEPREFIX"
setx PYTHONUTF8            $env:PYTHONUTF8
setx ROOT_SOURCECODES      "$env:ROOT_SOURCECODES"
setx ROOT_WORKSPACE        "$env:ROOT_WORKSPACE"
setx VISUAL                "$env:VISUAL"
setx YAZI_CONFIG_HOME      "$env:YAZI_CONFIG_HOME"
setx YAZI_FILE_ONE         "$env:YAZI_FILE_ONE"
setx YOZ_SERVER_PORT       "$env:YOZ_SERVER_PORT"

## Agent Environment ###############################################################################
$env:ANTHROPIC_BASE_URL               = "http://127.0.0.1:4747/api/claude"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL    = "claude-sonnet-5"
$env:ANTHROPIC_MODEL                  = "claude-opus-5[1m]"
$env:CLAUDE_CODE_SUBAGENT_MODEL       = "claude-opus-5[1m]"
$env:CLAUDE_CONFIG_DIR                = Join-Path $env:XDG_CONFIG_HOME "claude"
$env:CODEX_HOME                       = Join-Path $env:XDG_CONFIG_HOME "codex"
$env:OPENAI_BASE_URL                  = "http://127.0.0.1:4747/api/codex"
$env:GOOGLE_GEMINI_BASE_URL           = "http://127.0.0.1:4747/api/gemini"
$env:GEMINI_MODEL                     = "gemini-3-pro-preview"
$env:GEMINI_CONFIG_DIR                = Join-Path $env:USERPROFILE ".gemini"
$env:PI_CODING_AGENT_DIR              = Join-Path $env:XDG_CONFIG_HOME "pi"
$env:PI_CODING_AGENT_SESSION_DIR      = Join-Path $env:XDG_STATE_HOME "pi\sessions"

setx ANTHROPIC_BASE_URL               "$env:ANTHROPIC_BASE_URL"
setx ANTHROPIC_DEFAULT_HAIKU_MODEL    "$env:ANTHROPIC_DEFAULT_HAIKU_MODEL"
setx ANTHROPIC_MODEL                  "$env:ANTHROPIC_MODEL"
setx CLAUDE_CODE_SUBAGENT_MODEL       "$env:CLAUDE_CODE_SUBAGENT_MODEL"
setx CLAUDE_CONFIG_DIR                "$env:CLAUDE_CONFIG_DIR"
setx CODEX_HOME                       "$env:CODEX_HOME"
setx OPENAI_BASE_URL                  "$env:OPENAI_BASE_URL"
setx GOOGLE_GEMINI_BASE_URL           "$env:GOOGLE_GEMINI_BASE_URL"
setx GEMINI_MODEL                     "$env:GEMINI_MODEL"
setx GEMINI_CONFIG_DIR                "$env:GEMINI_CONFIG_DIR"
setx PI_CODING_AGENT_DIR              "$env:PI_CODING_AGENT_DIR"
setx PI_CODING_AGENT_SESSION_DIR      "$env:PI_CODING_AGENT_SESSION_DIR"

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
$repoworktree = Join-Path $env:USERPROFILE ".config\kit"
$repoGitPath = Join-Path $repomain ".git"
if (Test-Path -LiteralPath $repoGitPath) {
  git -C "$repomain" fetch origin
  if ($LASTEXITCODE -ne 0) {
    throw "[setup repo] failed to fetch origin in $repomain (exit code: $LASTEXITCODE)."
  }

  git -C "$repomain" merge origin/guanghechen --ff-only
  if ($LASTEXITCODE -ne 0) {
    throw "[setup repo] failed to fast-forward $repomain (exit code: $LASTEXITCODE)."
  }
} elseif (Test-Path -LiteralPath $repomain) {
  throw "[setup repo] path exists but is not a Git worktree: $repomain"
} else {
  New-Item -ItemType Directory -Path "$reporoot" -Force -ErrorAction Stop | Out-Null
  git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
  if ($LASTEXITCODE -ne 0) {
    throw "[setup repo] failed to clone $repomain (exit code: $LASTEXITCODE)."
  }
}

# Load default settings (checked in)
. "$repomain\env\setting.ps1"

Set-Location -Path $repomain
. .\setup\win\winget.ps1

Set-Location -Path $repomain
. .\setup\win\env\miniforge.ps1

Set-Location -Path $repomain
. .\setup\win\env\bun.ps1

Set-Location -Path $repomain
. .\setup\win\env\node.ps1

## Setup configs
### ensure kit worktree
if (Test-Path "$repoworktree\.git") {
  Write-Host "  [setup config] $repoworktree already exists. (skipped worktree)" -ForegroundColor Yellow
  git -C "$repoworktree" pull --ff-only origin kit
} else {
  git -C "$repomain" show-ref --verify --quiet refs/heads/kit
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [setup config] attaching existing branch kit to $repoworktree..." -ForegroundColor Cyan
    git -C "$repomain" worktree add "$repoworktree" kit
  } else {
    Write-Host "  [setup config] creating worktree $repoworktree from origin/kit..." -ForegroundColor Cyan
    git -C "$repomain" fetch origin
    git -C "$repomain" worktree add --track -b kit "$repoworktree" origin/kit
  }
}

### Setup settings
kit repo set config.edition "win"
kit repo sync

# The installer writes under CODEX_HOME, so run it after kit prepares the directory.
Set-Location -Path $repomain
. .\setup\win\env\codex.ps1

### Setup xdg configs
Set-Location -Path $repomain
. .\setup\win\config.ps1

####################################################################################################

Set-Location -Path $repomain
. .\setup\win\app\newsboat.ps1

Set-Location -Path $repomain
. .\setup\win\app\nvim.ps1

Set-Location -Path $repomain
try {
  & .\setup\win\bot\font-maple.ps1
} catch {
  Write-Host "  [setup font (Maple)] $($_.Exception.Message)" -ForegroundColor Yellow
}

Set-Location -Path $repomain
. .\setup\win\theme.ps1

Write-Host "`n ===== [setup settings] =====" -ForegroundColor Magenta
Write-Host "`n  [setup settings] preparing..." -ForegroundColor Cyan
Write-Host "  [setup settings] done." -ForegroundColor Green
