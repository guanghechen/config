function ghc-profile {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )

  $script = & kit profile --shell=pwsh @Args
  if ($LASTEXITCODE -ne 0) {
    return
  }

  Invoke-Expression $script
}
