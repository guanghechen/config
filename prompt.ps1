function prompt {
  $gitBranch = ""
  $addedCount = 0
  $modifiedCount = 0
  $untrackedCount = 0
  $aheadCount = 0
  $behindCount = 0

  $currentDir = Get-Location
  while ($true) {
    if (Test-Path (Join-Path $currentDir ".git")) {
      try {
        $gitStatus = git -C $currentDir status --porcelain=2 --branch 2>$null
        foreach ($line in $gitStatus) {
          if ($line.StartsWith("# branch.head ")) {
            $gitBranch = $line.Substring(14)
          }
          elseif ($line.StartsWith("# branch.ab ")) {
            if ($line -match '\+(\d+) \-(\d+)') {
              $aheadCount = [int]$Matches[1]
              $behindCount = [int]$Matches[2]
            }
          }
          elseif ($line.StartsWith("1 ") -or $line.StartsWith("2 ")) {
            $xy = $line.Substring(2, 2)
            if ($xy[0] -ne '.') { $addedCount++ }
            if ($xy[1] -ne '.') { $modifiedCount++ }
          }
          elseif ($line.StartsWith("? ")) {
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
  Write-Host "  " -nonewline -foregroundcolor DarkBlue
  Write-Host "`e[1m$env:USERNAME" -nonewline -foregroundcolor DarkRed
  Write-Host "@" -nonewline -foregroundcolor DarkGray
  Write-Host "`e[1m$env:COMPUTERNAME" -nonewline -foregroundcolor DarkCyan
  Write-Host " `e[1m$PWD" -nonewline -foregroundcolor DarkBlue
  Write-Host " " -nonewline

  if ($gitBranch -ne "") {
    Write-Host "(" -nonewline -foregroundcolor White
    Write-Host "`e[1m$gitBranch" -nonewline -foregroundcolor DarkMagenta
    if ($aheadCount -gt 0 -and $behindCount -gt 0) {
      Write-Host " ⇕$aheadCount/$behindCount" -nonewline -foregroundcolor DarkRed
    } elseif ($aheadCount -gt 0) {
      Write-Host " ↑$aheadCount" -nonewline -foregroundcolor DarkGreen
    } elseif ($behindCount -gt 0) {
      Write-Host " ↓$behindCount" -nonewline -foregroundcolor DarkRed
    }
    Write-Host "|" -nonewline -foregroundcolor White
    if ($addedCount -gt 0) {
      Write-Host "+$addedCount" -nonewline -foregroundcolor DarkBlue
    }
    if ($modifiedCount -gt 0) {
      Write-Host "●$modifiedCount" -nonewline -foregroundcolor DarkYellow
    }
    if ($untrackedCount -gt 0) {
      Write-Host "?$untrackedCount" -nonewline -foregroundcolor White
    }
    if ($addedCount -eq 0 -and $modifiedCount -eq 0 -and $untrackedCount -eq 0) {
      Write-Host "✔" -nonewline -foregroundcolor DarkGreen
    }
    Write-Host ") " -nonewline -foregroundcolor White
  }

  Write-Host (Get-Date -Format "HH:mm:ss") -nonewline -foregroundcolor DarkGray

  $conda_env_name = $env:CONDA_DEFAULT_ENV
  if ($conda_env_name -and $conda_env_name -ne "") {
    Write-Host " `e[1m($conda_env_name) " -nonewline -foregroundcolor DarkGreen
  }

  Write-Host
  Write-Host "PS>" -nonewline -foregroundcolor DarkCyan
  return " "
}
