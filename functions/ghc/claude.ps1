function ghc-claude-local {
    param(
        [string]$Port,
        [ValidateSet("opus", "sonnet")]
        [string]$Model = "opus"
    )

    $defaultVersion = "4.5"
    $apiPort = if ($Port) { $Port } else { $env:GHC_COPILOT_API_PORT }

    $selectedModel = switch ($Model) {
        "opus"   { "claude-opus-$defaultVersion" }
        "sonnet" { "claude-sonnet-$defaultVersion" }
    }

    Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    $env:ANTHROPIC_BASE_URL = "http://$env:GHC_COPILOT_API_HOST`:$apiPort"
    $env:ANTHROPIC_AUTH_TOKEN = $env:GHC_ANTHROPIC_AUTH_TOKEN
    $env:ANTHROPIC_MODEL = $selectedModel
    $env:ANTHROPIC_SMALL_FAST_MODEL = "claude-sonnet-$defaultVersion"
}

function ghc-claude-remote {
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_MODEL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL -ErrorAction SilentlyContinue
    $env:ANTHROPIC_API_KEY = $env:GHC_ANTHROPIC_API_KEY
}

