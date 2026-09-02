$minimumPowerShellVersion = [Version]"7.4.0"
if ($PSVersionTable.PSVersion -lt $minimumPowerShellVersion) {
  throw "[setup preparation] PowerShell $minimumPowerShellVersion or newer is required. Run this setup with pwsh."
}

Write-Host "`n`e[1;95m󰒓 setup`e[0m"
Write-Host "`n  [setup preparation] preparing..." -ForegroundColor Cyan

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

function Set-GhcUserEnvironmentVariable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Value
  )

  setx $Name $Value *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "[setup preparation] failed to persist user environment variable $Name (exit code: $LASTEXITCODE)."
  }
}

function Invoke-GhcPreparationCommand {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Action,

    [Parameter(Mandatory = $true)]
    [string]$FailureMessage
  )

  $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  $errorPreference = $ErrorActionPreference
  try {
    $PSNativeCommandUseErrorActionPreference = $false
    $ErrorActionPreference = "Continue"
    $output = @(& $Action 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $errorPreference
    $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
  }

  if ($exitCode -eq 0) {
    return
  }
  foreach ($item in $output) {
    foreach ($line in ($item.ToString() -split "`r?`n")) {
      if (-not [string]::IsNullOrWhiteSpace($line)) {
        Write-Host "  $line" -ForegroundColor Red
      }
    }
  }
  throw "$FailureMessage (exit code: $exitCode)."
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

Write-Host "  [setup preparation] persisting user environment..." -ForegroundColor Cyan
Set-GhcUserEnvironmentVariable APP_HOME_MINIFORGE    "$env:APP_HOME_MINIFORGE"
Set-GhcUserEnvironmentVariable APP_HOME_GIT          "$env:APP_HOME_GIT"
Set-GhcUserEnvironmentVariable XDG_CONFIG_HOME       "$env:XDG_CONFIG_HOME"
Set-GhcUserEnvironmentVariable XDG_DATA_HOME         "$env:XDG_DATA_HOME"
Set-GhcUserEnvironmentVariable XDG_STATE_HOME        "$env:XDG_STATE_HOME"
Set-GhcUserEnvironmentVariable BUN_INSTALL           "$env:BUN_INSTALL"
Set-GhcUserEnvironmentVariable CONDARC               "$env:CONDARC"
Set-GhcUserEnvironmentVariable CONDA_CHANGEPS1       "$env:CONDA_CHANGEPS1"
Set-GhcUserEnvironmentVariable EDITOR                "$env:EDITOR"
Set-GhcUserEnvironmentVariable FZF_DEFAULT_COMMAND   "$env:FZF_DEFAULT_COMMAND"
Set-GhcUserEnvironmentVariable FZF_DEFAULT_OPTS_FILE "$env:FZF_DEFAULT_OPTS_FILE"
Set-GhcUserEnvironmentVariable KOMOREBI_CONFIG_HOME  "$env:KOMOREBI_CONFIG_HOME"
Set-GhcUserEnvironmentVariable LG_CONFIG_FILE        "$env:LG_CONFIG_FILE"
Set-GhcUserEnvironmentVariable LS_COLORS             "$env:LS_COLORS"
Set-GhcUserEnvironmentVariable NODE_OPTIONS          "$env:NODE_OPTIONS"
Set-GhcUserEnvironmentVariable no_proxy              "$env:no_proxy"
Set-GhcUserEnvironmentVariable PYTHONIOENCODING      "$env:PYTHONIOENCODING"
Set-GhcUserEnvironmentVariable PYTHONPYCACHEPREFIX   "$env:PYTHONPYCACHEPREFIX"
Set-GhcUserEnvironmentVariable PYTHONUTF8            $env:PYTHONUTF8
Set-GhcUserEnvironmentVariable ROOT_SOURCECODES      "$env:ROOT_SOURCECODES"
Set-GhcUserEnvironmentVariable ROOT_WORKSPACE        "$env:ROOT_WORKSPACE"
Set-GhcUserEnvironmentVariable VISUAL                "$env:VISUAL"
Set-GhcUserEnvironmentVariable YAZI_CONFIG_HOME      "$env:YAZI_CONFIG_HOME"
Set-GhcUserEnvironmentVariable YAZI_FILE_ONE         "$env:YAZI_FILE_ONE"
Set-GhcUserEnvironmentVariable YOZ_SERVER_PORT       "$env:YOZ_SERVER_PORT"

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
$env:PI_TELEMETRY                     = 0

Set-GhcUserEnvironmentVariable ANTHROPIC_BASE_URL               "$env:ANTHROPIC_BASE_URL"
Set-GhcUserEnvironmentVariable ANTHROPIC_DEFAULT_HAIKU_MODEL    "$env:ANTHROPIC_DEFAULT_HAIKU_MODEL"
Set-GhcUserEnvironmentVariable ANTHROPIC_MODEL                  "$env:ANTHROPIC_MODEL"
Set-GhcUserEnvironmentVariable CLAUDE_CODE_SUBAGENT_MODEL       "$env:CLAUDE_CODE_SUBAGENT_MODEL"
Set-GhcUserEnvironmentVariable CLAUDE_CONFIG_DIR                "$env:CLAUDE_CONFIG_DIR"
Set-GhcUserEnvironmentVariable CODEX_HOME                       "$env:CODEX_HOME"
Set-GhcUserEnvironmentVariable OPENAI_BASE_URL                  "$env:OPENAI_BASE_URL"
Set-GhcUserEnvironmentVariable GOOGLE_GEMINI_BASE_URL           "$env:GOOGLE_GEMINI_BASE_URL"
Set-GhcUserEnvironmentVariable GEMINI_MODEL                     "$env:GEMINI_MODEL"
Set-GhcUserEnvironmentVariable GEMINI_CONFIG_DIR                "$env:GEMINI_CONFIG_DIR"
Set-GhcUserEnvironmentVariable PI_CODING_AGENT_DIR              "$env:PI_CODING_AGENT_DIR"
Set-GhcUserEnvironmentVariable PI_CODING_AGENT_SESSION_DIR      "$env:PI_CODING_AGENT_SESSION_DIR"
Set-GhcUserEnvironmentVariable PI_TELEMETRY                     "$env:PI_TELEMETRY"

####################################################################################################

## Conditional Environment ##########################################################################
if (Test-Path "$env:APP_HOME_GIT\bin\bash.exe") {
  $env:CLAUDE_CODE_GIT_BASH_PATH = "$env:APP_HOME_GIT\bin\bash.exe"
  Set-GhcUserEnvironmentVariable CLAUDE_CODE_GIT_BASH_PATH "$env:CLAUDE_CODE_GIT_BASH_PATH"
}
####################################################################################################

# Define the local path and repositories
$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $env:USERPROFILE ".config\guanghechen"
$repoworktree = Join-Path $env:USERPROFILE ".config\kit"
$repoGitPath = Join-Path $repomain ".git"
Write-Host "  [setup preparation] syncing repository..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $repoGitPath) {
  Invoke-GhcPreparationCommand {
    git -C "$repomain" fetch origin
  } "[setup repo] failed to fetch origin in $repomain"
  Invoke-GhcPreparationCommand {
    git -C "$repomain" merge origin/guanghechen --ff-only
  } "[setup repo] failed to fast-forward $repomain"
} elseif (Test-Path -LiteralPath $repomain) {
  throw "[setup repo] path exists but is not a Git worktree: $repomain"
} else {
  New-Item -ItemType Directory -Path "$reporoot" -Force -ErrorAction Stop | Out-Null
  Invoke-GhcPreparationCommand {
    git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
  } "[setup repo] failed to clone $repomain"
}

Write-Host "  [setup preparation] done." -ForegroundColor Green

$setupWin = Join-Path $repomain "setup\win"
. (Join-Path $setupWin "bot\step.ps1")

function Ensure-GhcKitWorktree {
  if (Test-Path -LiteralPath (Join-Path $repoworktree ".git")) {
    Write-Host "$repoworktree already exists (skipped worktree creation)" -ForegroundColor Yellow
    $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    try {
      $PSNativeCommandUseErrorActionPreference = $false
      git -C "$repoworktree" pull --ff-only origin kit
      $pullExitCode = $LASTEXITCODE
    } finally {
      $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
    }
    if ($pullExitCode -ne 0) {
      Write-Host "pull failed for $repoworktree (continuing)" -ForegroundColor Yellow
      $global:LASTEXITCODE = 0
    }
    return
  }

  $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  try {
    $PSNativeCommandUseErrorActionPreference = $false
    git -C "$repomain" show-ref --verify --quiet refs/heads/kit
    $showRefExitCode = $LASTEXITCODE
  } finally {
    $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
  }
  if ($showRefExitCode -eq 0) {
    Write-Host "attaching existing branch kit to $repoworktree..." -ForegroundColor Cyan
    git -C "$repomain" worktree add "$repoworktree" kit
    if ($LASTEXITCODE -ne 0) {
      throw "failed to attach the kit worktree (exit code: $LASTEXITCODE)"
    }
    return
  }

  Write-Host "creating worktree $repoworktree from origin/kit..." -ForegroundColor Cyan
  git -C "$repomain" fetch origin
  if ($LASTEXITCODE -ne 0) {
    throw "failed to fetch origin before creating the kit worktree (exit code: $LASTEXITCODE)"
  }
  git -C "$repomain" worktree add --track -b kit "$repoworktree" origin/kit
  if ($LASTEXITCODE -ne 0) {
    throw "failed to create the kit worktree (exit code: $LASTEXITCODE)"
  }
}

function Sync-GhcKitRepo {
  & $kitRepoBin set config.edition "win"
  if ($LASTEXITCODE -ne 0) {
    throw "failed to set config.edition (exit code: $LASTEXITCODE)"
  }
  & $kitRepoBin sync
  if ($LASTEXITCODE -ne 0) {
    throw "kit-repo sync failed (exit code: $LASTEXITCODE)"
  }
}

Set-Location -Path $repomain

## Bootstrap
Start-GhcSection "" bootstrap
Invoke-GhcStep "" "runtime settings" { . (Join-Path $repomain "env\setting.ps1") }
Invoke-GhcStep "" winget { & (Join-Path $setupWin "winget.ps1") } -Optional

## Environment
Start-GhcSection "" environment
Invoke-GhcStep "" miniforge { & (Join-Path $setupWin "env\miniforge.ps1") } -Optional
Invoke-GhcStep "" bun { & (Join-Path $setupWin "env\bun.ps1") } -Optional
Invoke-GhcStep "" node { & (Join-Path $setupWin "env\node.ps1") } -Optional

## Configuration
Start-GhcSection "" configuration
Invoke-GhcStep "" "cargo available" { Assert-GhcCommand cargo }
Invoke-GhcStep "󰏗" kit-repo { & (Join-Path $setupWin "env\kit-repo.ps1") }
$cargoHome = if ([string]::IsNullOrWhiteSpace($env:CARGO_HOME)) {
  Join-Path $env:USERPROFILE ".cargo"
} else {
  $env:CARGO_HOME
}
$kitRepoBin = Join-Path $cargoHome "local\bin\kit-repo.exe"
if (-not (Test-Path -LiteralPath $kitRepoBin -PathType Leaf)) {
  $kitRepoBin = Join-Path $cargoHome "bin\kit-repo.exe"
}
Invoke-GhcStep "󰙅" worktree { Ensure-GhcKitWorktree }
Write-Host ""
Sync-GhcKitRepo
Invoke-GhcStep "" config { & (Join-Path $setupWin "config.ps1") } -Optional
# The installer writes under CODEX_HOME, so run it after kit-repo prepares the directory.
Invoke-GhcStep "󰚩" codex { & (Join-Path $setupWin "env\codex.ps1") } -Optional

## Applications
Start-GhcSection "󱧺" applications
Invoke-GhcStep "" newsboat { & (Join-Path $setupWin "app\newsboat.ps1") } -Optional
Invoke-GhcStep "" nvim { & (Join-Path $setupWin "app\nvim.ps1") } -Optional
Invoke-GhcStep "" font { & (Join-Path $setupWin "bot\font-maple.ps1") } -Optional
Invoke-GhcStep "" "node available" { Assert-GhcCommand node }
Invoke-GhcStep "" theme { & (Join-Path $setupWin "theme.ps1") } -Optional

Complete-GhcSetup
