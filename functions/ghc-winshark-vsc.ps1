# Arm Wireshark TLS decryption for VS Code by dumping session keys to a keylog file.
# Run this BEFORE launching VS Code from the same shell; child processes inherit the env vars.
function ghc-winshark-vsc {
  if ([string]::IsNullOrWhiteSpace($env:d_wireshark_vsc_log)) {
    Write-Host "  Error: d_wireshark_vsc_log is not set or empty" -ForegroundColor Red
    return
  }

  $logDir = $env:d_wireshark_vsc_log
  if ((Test-Path $logDir) -and -not (Test-Path $logDir -PathType Container)) {
    Write-Host "  Error: d_wireshark_vsc_log exists but is not a directory: $logDir" -ForegroundColor Red
    return
  }

  if (-not (Test-Path $logDir -PathType Container)) {
    try {
      New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
    }
    catch {
      Write-Host "  Error: Failed to create directory: $logDir" -ForegroundColor Red
      return
    }
  }

  $logFile = Join-Path $logDir "vsc.log"
  $env:SSLKEYLOGFILE = $logFile
  $env:NODE_OPTIONS = "--tls-keylog=$logFile"

  Write-Host "  SSLKEYLOGFILE = $logFile" -ForegroundColor Green
  Write-Host "  NODE_OPTIONS  = --tls-keylog=$logFile" -ForegroundColor Green
}
