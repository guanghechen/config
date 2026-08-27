function pnpm-publish-otp --description 'Publish Changesets packages using an npm OTP'
    read --silent --prompt-str 'npm OTP: ' --local otp
    or return $status

    pnpm exec changeset publish --otp "$otp"
end
