# Linux interactive config

alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
alias ghc-gen-secret="node -e \"console.log(crypto.randomBytes(32).toString('base64'))\" | xsel --clipboard --input"
