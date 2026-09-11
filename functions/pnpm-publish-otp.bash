# shellcheck shell=bash
# Publish Changesets packages using an npm OTP.
pnpm-publish-otp() {
  local otp
  IFS= read -r -s -p 'npm OTP: ' otp || return $?

  pnpm exec changeset publish --otp "$otp"
}
