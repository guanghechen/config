### basic
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias cd..='cd ../'
alias cd...='cd ../../'
alias cd....='cd ../../../'
alias cd.....='cd ../../../../'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'
alias cp='cp -i'
alias diff='colordiff'
alias dir='dir --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='egrep --color=auto'
alias grep='egrep --color=auto'
alias ln='ln -i'
alias ls='ls --color=auto'
alias mkdir='mkdir -pv'
alias mv='mv -i'
alias rm='rm -i -I'
alias tree-list='tree --dirsfirst -aCF'
alias vdir='vdir --color=auto'

### fzf
alias fzf="FZF_DEFAULT_OPTS_FILE=$HOME/.config/fzf/default.fzfrc $HOMEBREW_PREFIX/bin/fzf"
alias fvim='FZF_DEFAULT_OPTS_FILE=$HOME/.config/fzf/nvim.fzfrc $HOMEBREW_PREFIX/bin/fzf --print0 | xargs -0 -o nvim'

### nvim
alias vim="$HOMEBREW_PREFIX/bin/nvim"
alias vi="$HOMEBREW_PREFIX/bin/nvim"
alias nvchad="NVIM_APPNAME=nvim-nvchad $HOMEBREW_PREFIX/bin/nvim"
alias lazyvim="NVIM_APPNAME=nvim-lazy $HOMEBREW_PREFIX/bin/nvim"

### tmux
alias tnew='tmux new -s'                # Create a new tmux session
alias tkill='tmux kill-session -t'      # Kill a tmux session
alias tkill-all='tmux list-sessions | awk \'{print $1}\' | xargs -n 1 tmux kill-session -t'
alias tdetach='tmux detach'             # Detach from the session
alias tattach='tmux attach -t'          # Attach to a session
alias takeover='tmux detach -a'         # Detach other clients from the session
alias watch-fake-clipboard="nohup bash $HOME/.config/tmux/script/fake-clipboard.sh /opt/me/data/clipboard/fake.txt &!"
alias tmux-use-fake-clipboard="tmux set-environment ghc_use_fake_clipboard /opt/me/data/clipboard/fake.txt"

### misc
alias ghc-ports='netstat -tulanp'
alias reset-gpg-agent='gpgconf --kill gpg-agent'
alias start-pfctl='sudo pfctl -ef /etc/pf.conf'
