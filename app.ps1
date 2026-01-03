## claude
function ccc {
  claude --dangerously-skip-permissions @args
}

function cc0 {
  $env:ANTHROPIC_API_KEY = ''
  $env:ANTHROPIC_BASE_URL = $env:GHC_ANTHROPIC_BASE_URL
  $env:ANTHROPIC_AUTH_TOKEN = $env:GHC_ANTHROPIC_AUTH_TOKEN
  $env:ANTHROPIC_MODEL = 'claude-opus-4.5'
  $env:ANTHROPIC_SMALL_FAST_MODEL = 'claude-sonnet-4.5'
  claude --dangerously-skip-permissions @args
}

## codex
function cx0 {
  codex --profile=github-copilot --dangerously-bypass-approvals-and-sandbox @args
}

function cx1 {
  codex --profile=azure --dangerously-bypass-approvals-and-sandbox @args
}

## conda (lazy)
function conda {
  if (-not $env:__CONDA_INITIALIZED) {
    if (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
      (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
      $env:__CONDA_INITIALIZED = "1"
      Remove-Item -Path Function:conda -ErrorAction SilentlyContinue
    }
  }
  & conda @args
}

## fnm (lazy)
function __fnm_init__ {
  if (-not $env:__FNM_INITIALIZED) {
    fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
    $env:__FNM_INITIALIZED = "1"
    Remove-Item -Path Function:node, Function:npm, Function:npx, Function:pnpm -ErrorAction SilentlyContinue
  }
}
function node { __fnm_init__; node @args }
function npm { __fnm_init__; npm @args }
function npx { __fnm_init__; npx @args }
function pnpm { __fnm_init__; pnpm @args }

## gemini
function ggg {
  gemini --model='gemini-3-pro-preview' --yolo @args
}

function gg0 {
  $env:GOOGLE_CLOUD_PROJECT = ''
  $env:GOOGLE_GEMINI_BASE_URL = $env:GHC_GEMINI_BASE_URL
  $env:GEMINI_API_KEY = $env:GHC_GEMINI_AUTH_TOKEN
  gemini --model='gemini-3-pro-preview' --yolo @args
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
function z { __zoxide_init__; & z @args }
function zi { __zoxide_init__; & zi @args }
