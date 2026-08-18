function ghc-update {
  git -C "$env:XDG_CONFIG_HOME\kit" pull origin kit
  if ($LASTEXITCODE -eq 0) { kit-repo sync }
}
