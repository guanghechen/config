Write-Host "`n  [cleanup stale env] preparing..." -ForegroundColor Cyan

# ANTHROPIC_SMALL_FAST_MODEL was persisted by earlier revisions of setup.ps1 and is no longer
# written. Dropping the assignment is not enough on a machine that already ran an older bootstrap:
# `setx` cannot delete a variable, so the old value survives in HKCU\Environment.
#
# This one has to be removed rather than merely left behind, because Claude Code resolves its
# haiku slot with envVarPriority ["ANTHROPIC_SMALL_FAST_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL"] —
# the deprecated name is read *first*, so a leftover copy silently outranks what setup.ps1 writes.
#
# Deliberately narrow: other variables setup.ps1 stopped writing (LIBCLANG_PATH, MYVIMRC) are inert
# when stale, and deleting them on every run would silently undo a value the user set by hand —
# `ghc-upgrade` re-runs this script. Remove those manually if you want them gone.
$staleVariables = @(
  "ANTHROPIC_SMALL_FAST_MODEL"
)

foreach ($name in $staleVariables) {
  # `$null -ne` rather than a truthiness test: `setx VAR ""` writes a zero-length value, which is
  # falsy in PowerShell but still present in the registry.
  if ($null -ne [Environment]::GetEnvironmentVariable($name, "User")) {
    Write-Host "  [cleanup stale env] removing $name" -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable($name, $null, "User")
  }

  # Also drop it from this process so the rest of the bootstrap sees the post-cleanup state.
  [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

Write-Host "  [cleanup stale env] done." -ForegroundColor Green
