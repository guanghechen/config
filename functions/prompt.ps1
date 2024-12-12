function prompt {
  $gitBranch = ""
  $addedCount = 0
  $modifiedCount = 0
  $untrackedCount = 0

  $currentDir = Get-Location
  while ($true) {
    if (Test-Path (Join-Path $currentDir ".git")) {
      try {
        $gitBranch = git -C $currentDir rev-parse --abbrev-ref HEAD 2>$null
        $gitStatus = git -C $currentDir status --porcelain 2>$null
        foreach ($line in $gitStatus) {
          $line_status = $line.TrimStart()
          if ($line_status.StartsWith("A")) {
            $addedCount++
          }
          if ($line_status.StartsWith("M") -or $line_status.StartsWith("D")) {
            $modifiedCount++
          }
          if ($line_status.StartsWith("??")) {
            $untrackedCount++
          }
        }
      } catch {}
      break
    }

    $parentDir = [System.IO.Directory]::GetParent($currentDir)
    if (-not $parentDir) {
      break
    }
    $currentDir = $parentDir.FullName

  }

  Write-Host
  Write-Host "  " -nonewline -foregroundcolor Blue
  Write-Host "`e[1m$env:USERNAME" -nonewline -foregroundcolor Red
  Write-Host "@" -nonewline -foregroundcolor Cyan
  Write-Host "`e[1m$env:COMPUTERNAME" -nonewline -foregroundcolor White
  Write-Host " `e[1m$PWD" -nonewline -foregroundcolor DarkBlue
  Write-Host " " -nonewline

  if ($gitBranch -ne "") {
    Write-Host "(" -nonewline -foregroundcolor White
    Write-Host "`e[1m$gitBranch" -nonewline -foregroundcolor Magenta
    Write-Host "|" -nonewline -foregroundcolor White
    if ($addedCount -gt 0) {
      Write-Host "+$addedCount" -nonewline -foregroundcolor DarkBlue
    }
    if ($modifiedCount -gt 0) {
      Write-Host "●$modifiedCount" -nonewline -foregroundcolor Yellow
    }
    if ($untrackedCount -gt 0) {
      Write-Host "?$untrackedCount" -nonewline -foregroundcolor White
    }
    if ($addedCount -eq 0 -and $modifiedCount -eq 0 -and $untrackedCount -eq 0) {
      Write-Host "" -nonewline -foregroundcolor Green
    }
    Write-Host ") " -nonewline -foregroundcolor White
  }

  Write-Host (Get-Date -Format "HH:mm:ss") -nonewline -foregroundcolor DarkGray

  $conda_env_name = $env:CONDA_DEFAULT_ENV
  if ($conda_env_name -and $conda_env_name -ne "") {
    Write-Host " `e[1m($conda_env_name) " -nonewline -foregroundcolor Green
  }

  Write-Host
  Write-Host "PS>" -nonewline -foregroundcolor Cyan
  return " "
}
