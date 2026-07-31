if (fnm list | Select-String -Quiet "v$env:GHC_APP_EDITION_NODE") {
  Write-Host "`n  [setup node] node@$env:GHC_APP_EDITION_NODE is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "`n  [setup node] installing node@$env:GHC_APP_EDITION_NODE..." -ForegroundColor Cyan
  fnm install $env:GHC_APP_EDITION_NODE
}

fnm use $env:GHC_APP_EDITION_NODE
fnm default $env:GHC_APP_EDITION_NODE

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "[setup node] npm is unavailable after activating node@$env:GHC_APP_EDITION_NODE."
}

## Setup tree-sitter-cli
npm list -g --depth=0 tree-sitter-cli *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Host "  [setup node] tree-sitter-cli is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup node] installing tree-sitter-cli..." -ForegroundColor Cyan
  npm install -g tree-sitter-cli
}

Write-Host "  [setup node] installing @guanghechen/kit" -ForegroundColor Cyan
npm install -g @guanghechen/kit

## Setup agents
foreach ($pkg in @("@anthropic-ai/claude-code", "@google/gemini-cli")) {
  npm list -g --depth=0 "$pkg" *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "  [setup node] $pkg is already installed. (skipped)" -ForegroundColor Yellow
  } else {
    Write-Host "  [setup node] installing $pkg..." -ForegroundColor Cyan
    npm install -g $pkg
  }
}
