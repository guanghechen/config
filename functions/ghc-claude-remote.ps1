function ghc-claude-remote {
  Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_MODEL -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL -ErrorAction SilentlyContinue
  $env:ANTHROPIC_API_KEY = $env:GHC_ANTHROPIC_API_KEY
}
