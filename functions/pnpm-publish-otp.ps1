# Publish Changesets packages using an npm OTP.
function pnpm-publish-otp {
  $otp = Read-Host -Prompt 'npm OTP' -AsSecureString -ErrorAction Stop
  $credential = [System.Management.Automation.PSCredential]::new('otp', $otp)

  & pnpm exec changeset publish --otp ($credential.GetNetworkCredential().Password)
}
