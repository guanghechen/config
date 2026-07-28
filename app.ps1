## claude
function ccc {
  claude --dangerously-skip-permissions @args
}

function cc0 {
  $env:ANTHROPIC_API_KEY = ''
  $env:ANTHROPIC_BASE_URL = $env:GHC_ANTHROPIC_BASE_URL
  $env:ANTHROPIC_AUTH_TOKEN = $env:GHC_ANTHROPIC_AUTH_TOKEN
  $env:ANTHROPIC_MODEL = 'claude-opus-4-8[1m]'
  $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = 'claude-sonnet-5'
  claude --dangerously-skip-permissions @args
}

## codex
function cx0 {
  codex -p copilot --dangerously-bypass-approvals-and-sandbox @args
}

function cxd {
  codex -p copilot-dev --dangerously-bypass-approvals-and-sandbox @args
}


## conda (lazy)
function __conda_init__ {
  if (-not $env:__CONDA_INITIALIZED) {
    if (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
      (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
    }
    $env:__CONDA_INITIALIZED = "1"
    Remove-Item -Path Function:conda -ErrorAction SilentlyContinue
  }
}
function conda {
  __conda_init__
  & conda @args
}

## gemini
function gg0 {
  $env:GOOGLE_CLOUD_PROJECT = ""
  $env:GOOGLE_GEMINI_BASE_URL = "http://127.0.0.1:4747/api/gemini"
  gemini --model="gemini-3-pro-preview" --yolo @args
}

function ggg {
  gemini --model="gemini-3-pro-preview" --yolo @args
}

## lazygit
Set-Alias lg lazygit

## lsd
function ll {
  lsd -l @args
}

## yazi
function y {
  $tmp = [System.IO.Path]::GetTempFileName()
  yazi @args --cwd-file="$tmp"
  $cwd = Get-Content -Path $tmp
  if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
    Set-Location -LiteralPath $cwd
  }
  Remove-Item -Path $tmp
}

## zoxide (lazy)
function __zoxide_init__ {
  if (-not $env:__ZOXIDE_INITIALIZED) {
    zoxide init powershell | Out-String | Invoke-Expression
    $env:__ZOXIDE_INITIALIZED = "1"
  }
}

function z {
  __zoxide_init__
  & z @args
}

function zi {
  __zoxide_init__
  & zi @args
}
