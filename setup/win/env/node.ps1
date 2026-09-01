function Test-NpmPackageInstalled {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Package
  )

  $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  try {
    $PSNativeCommandUseErrorActionPreference = $false
    npm list -g --depth=0 "$Package" *> $null
    return $LASTEXITCODE -eq 0
  } finally {
    $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
  }
}

if (fnm list | Select-String -Quiet "v$env:GHC_APP_EDITION_NODE") {
  Write-Host "node@$env:GHC_APP_EDITION_NODE is already installed (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "installing node@$env:GHC_APP_EDITION_NODE..." -ForegroundColor Cyan
  fnm install $env:GHC_APP_EDITION_NODE
  if ($LASTEXITCODE -ne 0) {
    throw "[setup node] failed to install node@$env:GHC_APP_EDITION_NODE (exit code: $LASTEXITCODE)."
  }
}

fnm use $env:GHC_APP_EDITION_NODE
if ($LASTEXITCODE -ne 0) {
  throw "[setup node] failed to activate node@$env:GHC_APP_EDITION_NODE (exit code: $LASTEXITCODE)."
}
fnm default $env:GHC_APP_EDITION_NODE
if ($LASTEXITCODE -ne 0) {
  throw "[setup node] failed to set node@$env:GHC_APP_EDITION_NODE as default (exit code: $LASTEXITCODE)."
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "[setup node] npm is unavailable after activating node@$env:GHC_APP_EDITION_NODE."
}

## Setup tree-sitter-cli
if (Test-NpmPackageInstalled tree-sitter-cli) {
  Write-Host "tree-sitter-cli is already installed (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "installing tree-sitter-cli..." -ForegroundColor Cyan
  npm install -g tree-sitter-cli
  if ($LASTEXITCODE -ne 0) {
    throw "[setup node] failed to install tree-sitter-cli (exit code: $LASTEXITCODE)."
  }
}

## Setup agents
foreach ($pkg in @("@anthropic-ai/claude-code", "@google/gemini-cli")) {
  if (Test-NpmPackageInstalled "$pkg") {
    Write-Host "$pkg is already installed (skipped)" -ForegroundColor Yellow
  } else {
    Write-Host "installing $pkg..." -ForegroundColor Cyan
    npm install -g $pkg
    if ($LASTEXITCODE -ne 0) {
      throw "[setup node] failed to install $pkg (exit code: $LASTEXITCODE)."
    }
  }
}
