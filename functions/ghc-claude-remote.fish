function ghc-claude-remote
    set -ge ANTHROPIC_BASE_URL
    set -ge ANTHROPIC_AUTH_TOKEN
    set -ge ANTHROPIC_MODEL
    set -ge ANTHROPIC_SMALL_FAST_MODEL
    set -gx ANTHROPIC_API_KEY $GHC_ANTHROPIC_API_KEY
end
