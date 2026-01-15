function ghc-opensource {
  param (
    [Parameter(Position = 0)]
    [string]$Arg1,
    [Parameter(Position = 1)]
    [string]$Arg2
  )

  if (-not ${env:ROOT_SOURCECODES}) {
    Write-Host "  ROOT_SOURCECODES is not set." -ForegroundColor Red
    return
  }

  $platform = "--github"
  $repoPath = $null

  if ($Arg1 -eq "--github") {
    $platform = "--github"
    $repoPath = $Arg2
  } elseif ($Arg1) {
    $repoPath = $Arg1
  }

  if (-not $repoPath) {
    Write-Host "  Usage: ghc-opensource [--github] <author/reponame>" -ForegroundColor Yellow
    return
  }

  switch ($platform) {
    "--github" {
      $parts = $repoPath -split "/"
      if ($parts.Count -ne 2) {
        Write-Host "  Invalid format. Expected <author/reponame>." -ForegroundColor Red
        return
      }

      $author = $parts[0]
      $reponame = $parts[1]
      $targetDir = Join-Path ${env:ROOT_SOURCECODES} "github" $author $reponame
      $parentDir = Join-Path ${env:ROOT_SOURCECODES} "github" $author

      if (Test-Path (Join-Path $targetDir ".git")) {
        git -C $targetDir pull origin
        if ($LASTEXITCODE -ne 0) { return }
        Set-Location $targetDir
        return
      }

      if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
      }
      git -C $parentDir clone "https://github.com/${author}/${reponame}.git"
      if ($LASTEXITCODE -ne 0) { return }
      Set-Location $targetDir
    }
  }
}
