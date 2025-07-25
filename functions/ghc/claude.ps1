function ghc-claude-local {
    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    $env:ANTHROPIC_BASE_URL = "http://$env:GHC_COPILOT_API_HOST`:$env:GHC_COPILOT_API_PORT"
    $env:ANTHROPIC_AUTH_TOKEN = $env:GHC_ANTHROPIC_AUTH_TOKEN
    $env:ANTHROPIC_MODEL = "claude-sonnet-4"
    $env:ANTHROPIC_SMALL_FAST_MODEL = "claude-3.7-sonnet"
}

function ghc-claude-remote {
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL -ErrorAction SilentlyContinue
    $env:ANTHROPIC_API_KEY = $env:GHC_ANTHROPIC_API_KEY
}

