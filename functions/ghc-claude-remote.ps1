function ghc-claude-remote {
  Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_MODEL -ErrorAction SilentlyContinue
  Remove-Item Env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ErrorAction SilentlyContinue
  # Read before ANTHROPIC_DEFAULT_HAIKU_MODEL; a machine that predates the rename may still carry it.
  Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL -ErrorAction SilentlyContinue
  $env:ANTHROPIC_API_KEY = $env:GHC_ANTHROPIC_API_KEY
}
