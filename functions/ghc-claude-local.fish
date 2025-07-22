function ghc-claude-local
    set -ge ANTHROPIC_API_KEY
    set -gx ANTHROPIC_BASE_URL "http://$GHC_COPILOT_API_HOST:$GHC_COPILOT_API_PORT"
    set -gx ANTHROPIC_AUTH_TOKEN $GHC_ANTHROPIC_AUTH_TOKEN
    set -gx ANTHROPIC_MODEL claude-sonnet-4
    set -gx ANTHROPIC_SMALL_FAST_MODEL claude-3.7-sonnet
end
