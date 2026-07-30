if (fnm list | Select-String -Quiet "v$env:GHC_APP_EDITION_NODE") {
  Write-Host "`n  [setup node] node@$env:GHC_APP_EDITION_NODE is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "`n  [setup node] installing node@$env:GHC_APP_EDITION_NODE..." -ForegroundColor Cyan
  fnm install $env:GHC_APP_EDITION_NODE
}

fnm use $env:GHC_APP_EDITION_NODE
fnm default $env:GHC_APP_EDITION_NODE

## Setup tree-sitter-cli
if (npm list -g tree-sitter-cli 2>$null) {
  Write-Host "  [setup node] tree-sitter-cli is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup node] installing tree-sitter-cli..." -ForegroundColor Cyan
  npm install -g tree-sitter-cli
}

Write-Host "  [setup node] installing @guanghechen/kit" -ForegroundColor Cyan
npm install -g @guanghechen/kit

## Setup agents
foreach ($pkg in @("@anthropic-ai/claude-code", "@google/gemini-cli")) {
  if (npm list -g $pkg 2>$null) {
    Write-Host "  [setup node] $pkg is already installed. (skipped)" -ForegroundColor Yellow
  } else {
    Write-Host "  [setup node] installing $pkg..." -ForegroundColor Cyan
    npm install -g $pkg
  }
}
