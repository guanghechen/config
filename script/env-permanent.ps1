# Persist the secrets loaded from `local/env.ps1`, which is gitignored and therefore
# not available to setup/win/setup.ps1. Everything else in the agent env (base URLs,
# model ids, config dirs) is persisted by setup/win/setup.ps1 — do not duplicate it
# here, or a session missing one of those vars will setx it to an empty value.
foreach ($name in @("ANTHROPIC_AUTH_TOKEN", "GEMINI_API_KEY")) {
  $value = [Environment]::GetEnvironmentVariable($name, "Process")
  if ([string]::IsNullOrEmpty($value)) {
    Write-Host "  [env permanent] $name is not set in this session. (skipped)" -ForegroundColor Yellow
    continue
  }

  setx $name "$value"
}
