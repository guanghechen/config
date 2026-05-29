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

  if (-not (Test-Path ${env:ROOT_SOURCECODES})) {
    Write-Host "  ROOT_SOURCECODES path does not exist: ${env:ROOT_SOURCECODES}" -ForegroundColor Red
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
    Write-Host "  Usage: ghc-opensource [--github] <author/reponame|github-url>" -ForegroundColor Yellow
    return
  }

  if ($platform -eq "--github") {
    $githubUrlMatch = [regex]::Match($repoPath, '^https?://github\.com/([^/?#]+)/([^/?#]+)')
    if ($githubUrlMatch.Success) {
      $ownerName = $githubUrlMatch.Groups[1].Value
      $repoName = $githubUrlMatch.Groups[2].Value -replace '\.git$', ''
      $reservedGithubPaths = @(
        "about", "account", "apps", "blog", "business", "codespaces", "collections", "contact",
        "customer-stories", "dashboard", "enterprise", "events", "explore", "features",
        "github-copilot", "join", "login", "marketplace", "new", "notifications", "orgs",
        "organizations", "pricing", "pulls", "repositories", "search", "security", "settings",
        "showcases", "sponsors", "topics", "trending", "users"
      )
      $ownerNamePattern = '^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
      $repoNamePattern = '^[A-Za-z0-9._-]+$'
      $isReservedGithubPath = $reservedGithubPaths -contains $ownerName.ToLowerInvariant()
      $isValidOwnerName = $ownerName -match $ownerNamePattern
      $isValidRepoName = $repoName -match $repoNamePattern

      if (-not $isReservedGithubPath -and $isValidOwnerName -and $isValidRepoName) {
        $repoPath = "$ownerName/$repoName"
      }
    }
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
      git clone "https://github.com/${author}/${reponame}.git" $targetDir
      if ($LASTEXITCODE -ne 0) { return }
      Set-Location $targetDir
    }
  }
}
