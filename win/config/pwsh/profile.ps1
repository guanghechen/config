Set-PSReadLineOption -EditMode Vi
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

## Setup conda
If (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
  (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression

  #  conda config --set auto_activate_base false
  #  if (conda env list | Select-String -Pattern "^lemon\s") {
  #    conda activate lemon
  #  }
}

## Setup fnm
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression

## Setup zoxide (need move to the last line. see https://github.com/ajeetdsouza/zoxide/issues/707#issuecomment-1959685345)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

function prompt {
  Write-Host
  Write-Host "  " -nonewline -foregroundcolor Blue
  Write-Host "`e[1m$env:USERNAME" -nonewline -foregroundcolor Red
  Write-Host "@" -nonewline -foregroundcolor Cyan
  Write-Host "`e[1m$env:COMPUTERNAME" -nonewline -foregroundcolor White
  Write-Host " `e[1m$PWD" -nonewline -foregroundcolor DarkBlue
  Write-Host " " -nonewline

  if (Test-Path ".git") {
    try {
      $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
      Write-Host "(" -nonewline -foregroundcolor White
      Write-Host "`e[1m$gitBranch" -nonewline -foregroundcolor Magenta
      Write-Host "|" -nonewline -foregroundcolor White

      $gitStatus = git status --porcelain 2>$null
      $addedCount = 0
      $modifiedCount = 0
      $untrackedCount = 0
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

      if ($addedCount -gt 0) {
        Write-Host "+$addedCount" -nonewline -foregroundcolor DarkBlue
      }
      if ($modifiedCount -gt 0) {
        Write-Host "✗$modifiedCount" -nonewline -foregroundcolor Yellow
      }
      if ($untrackedCount -gt 0) {
        Write-Host "?$untrackedCount" -nonewline -foregroundcolor White
      }
      if ($addedCount -eq 0 -and $modifiedCount -eq 0 -and $untrackedCount -eq 0) {
        Write-Host "" -nonewline -foregroundcolor Green
      }

      Write-Host ") " -nonewline -foregroundcolor White
    } catch {}
  }

  Write-Host (Get-Date -Format "HH:mm:ss") -nonewline -foregroundcolor DarkGray
  Write-Host
  Write-Host "PS>" -nonewline -foregroundcolor Cyan
  return " "
}
