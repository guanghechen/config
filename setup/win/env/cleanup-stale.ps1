# Run manually, once, on a machine that was bootstrapped by an older revision of setup.ps1.
#
#   pwsh -File .\setup\win\env\cleanup-stale.ps1
#
# Not sourced by setup.ps1 — removing persisted state is a deliberate, one-off action, not
# something a routine `ghc-upgrade` should do behind your back.
#
# ANTHROPIC_SMALL_FAST_MODEL was persisted by earlier revisions of setup.ps1 and is no longer
# written. Dropping the assignment is not enough on a machine that already ran an older bootstrap:
# `setx` cannot delete a variable, so the old value survives in HKCU\Environment.
#
# It has to be removed rather than merely left behind, because Claude Code resolves its haiku slot
# with envVarPriority ["ANTHROPIC_SMALL_FAST_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL"] — the
# deprecated name is read *first*, so a leftover copy silently outranks what setup.ps1 writes.
#
# Deliberately narrow: other variables setup.ps1 stopped writing (LIBCLANG_PATH, MYVIMRC) are inert
# when stale. Add them here only if you actually want them gone.
Write-Host "`n  [cleanup stale env] preparing..." -ForegroundColor Cyan

$staleVariables = @(
  "ANTHROPIC_SMALL_FAST_MODEL"
)

foreach ($name in $staleVariables) {
  # `$null -ne` rather than a truthiness test: `setx VAR ""` writes a zero-length value, which is
  # falsy in PowerShell but still present in the registry.
  if ($null -ne [Environment]::GetEnvironmentVariable($name, "User")) {
    Write-Host "  [cleanup stale env] removing $name" -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable($name, $null, "User")
  } else {
    Write-Host "  [cleanup stale env] $name is not set. (skipped)" -ForegroundColor Yellow
  }

  [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

Write-Host "  [cleanup stale env] done." -ForegroundColor Green
