Set-Alias lg lazygit

function ll {
  lsd -l $args
}

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

