### basic
abbr -a ll      'lsd -la'
abbr -a ..      'cd ../'
abbr -a ...     'cd ../../'
abbr -a ....    'cd ../../../'
abbr -a .....   'cd ../../../../'
abbr -a .1      'cd ../'
abbr -a .2      'cd ../../'
abbr -a .3      'cd ../../../'
abbr -a .4      'cd ../../../../'
abbr -a .5      'cd ../../../../../'
abbr -a cd..    'cd ../'
abbr -a cd...   'cd ../../'
abbr -a cd....  'cd ../../../'
abbr -a cd..... 'cd ../../../../'
abbr -a gr      'git remote -v | awk \'{print $2}\' | head -1'
alias chown='chown --preserve-root'
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
alias ports='netstat -tulanp'
alias rm='rm -i -I'
alias sss='source ~/.config/fish/config.fish'
alias tls='tree --dirsfirst -aCF'
alias vdir='vdir --color=auto'

### claude code
alias ccc='claude --dangerously-skip-permissions'
alias spec-status='bash .specify/scripts/bash/check-prerequisites.sh'

### fzf
alias fzf="$HOMEBREW_PREFIX/bin/fzf"
alias fvim='$HOMEBREW_PREFIX/bin/fzf --print0 | xargs -0 -o nvim'

### lazygit
if test -f "$HOME/.config/lazygit/local/theme.yml"
    alias lg="lazygit -ucf '$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/local/theme.yml'"
else
    alias lg="lazygit -ucf '$HOME/.config/lazygit/config.yml'"
end

### nvim
if set -q NEOVIM_HOME; and test -n "$NEOVIM_HOME"
    alias vim="$NEOVIM_HOME/bin/nvim"
    alias vi="$NEOVIM_HOME/bin/nvim"
    alias nvchad="NVIM_APPNAME=nvim-nvchad $NEOVIM_HOME/bin/nvim"
    alias nvchad-debug="NVIM_APPNAME=nvim-nvchad-debug $NEOVIM_HOME/bin/nvim"
    alias nvdebug="NVIM_APPNAME=nvim-debug $NEOVIM_HOME/bin/nvim"
    alias lazyvim="NVIM_APPNAME=nvim-lazy $NEOVIM_HOME/bin/nvim"
end

### tmux
alias tnew='tmux new -s' # Create a new tmux session
alias tkill='tmux kill-session -t' # Kill a tmux session
alias tkill-all='tmux list-sessions | awk -F: \'{print $1}\' | xargs -I {} tmux kill-session -t "{}"'
alias tdetach='tmux detach' # Detach from the session
alias tattach='tmux attach -t' # Attach to a session
alias tdetach-others='tmux detach -a' # Detach other clients from the session
alias tmux-use-fake-clipboard="tmux set-environment ghc_use_fake_clipboard /opt/me/data/clipboard/fake.txt"
alias watch-fake-clipboard="nohup bash $HOME/.config/tmux/script/fake-clipboard.sh /opt/me/data/clipboard/fake.txt &!"

### misc
alias ghc-clock='tty-clock -DSbcnrs -C5'
alias ghc-ports='netstat -tulanp'
alias reset-gpg-agent='gpgconf --kill gpg-agent'
alias start-pfctl='sudo pfctl -ef /etc/pf.conf'
alias today='cal -C3'

## Run python server with poetry
# alias pydemo-server='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-debug='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m debugpy --listen 9527 -m uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-debug-wait='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m debugpy --listen 9527 --wait-for-client -m uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-client='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m <client_entry> --server-endpoint=http://localhost:9528'
