# Linux interactive config

alias chmod='chmod --preserve-root'
alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | xsel --clipboard --input"
