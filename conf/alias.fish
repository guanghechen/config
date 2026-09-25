### basic
abbr -a .. 'cd ../'
abbr -a ... 'cd ../../'
abbr -a .... 'cd ../../../'
abbr -a ..... 'cd ../../../../'
abbr -a .1 'cd ../'
abbr -a .2 'cd ../../'
abbr -a .3 'cd ../../../'
abbr -a .4 'cd ../../../../'
abbr -a .5 'cd ../../../../../'
abbr -a cd.. 'cd ../'
abbr -a cd... 'cd ../../'
abbr -a cd.... 'cd ../../../'
abbr -a cd..... 'cd ../../../../'
abbr -a gr 'git remote -v | awk \'{print $2}\' | head -1'
abbr -a ll 'lsd -l'
abbr -a ports 'netstat -tulanp'
abbr -a tf 'touch (date +%Y%m%d_%H%M%S).log'
abbr -a tls 'tree --dirsfirst -aCF'

alias chown='chown --preserve-root'
alias chgrp='chgrp --preserve-root'
alias cp='cp -i'
alias diff='colordiff'
alias dir='dir --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='command grep -F --color=auto'
alias gdiff='GIT_PAGER=delta git diff'
alias grep='egrep --color=auto'
alias ln='ln -i'
alias ls='ls --color=auto'
alias mkdir='mkdir -pv'
alias mv='mv -i'
alias rm='rm -i -I'
alias vdir='vdir --color=auto'

### claude code
abbr -a ccc 'claude --dangerously-skip-permissions'

### codex
abbr -a cx0 'FORCE_COLOR=1 codex -p copilot --dangerously-bypass-approvals-and-sandbox'
abbr -a cxd 'FORCE_COLOR=1 codex -p copilot-dev --dangerously-bypass-approvals-and-sandbox'
abbr -a cxf 'FORCE_COLOR=1 codex -p copilot-fast --dangerously-bypass-approvals-and-sandbox'
abbr -a cxm 'FORCE_COLOR=1 codex -p copilot-max --dangerously-bypass-approvals-and-sandbox'

### gemini
abbr -a ggg 'gemini --model="gemini-3-pro-preview" --yolo'

### fzf
if set -q HOMEBREW_PREFIX; and test -x "$HOMEBREW_PREFIX/bin/fzf"
    alias fzf="$HOMEBREW_PREFIX/bin/fzf"
end
abbr -a fvim 'fzf --print0 | xargs -0 -o nvim'

### lazygit
if test -f "$HOME/.config/lazygit/local/theme.yml"
    abbr -a lg "lazygit -ucf '$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/local/theme.yml'"
else
    abbr -a lg "lazygit -ucf '$HOME/.config/lazygit/config.yml'"
end

### lst
abbr -a lst 'lsd --tree -I .git -I node_modules'

### nvim
if set -q NEOVIM_HOME; and test -n "$NEOVIM_HOME"
    alias vim="$NEOVIM_HOME/bin/nvim"
    alias vi="$NEOVIM_HOME/bin/nvim"
    abbr -a nvchad "NVIM_APPNAME=nvim-nvchad $NEOVIM_HOME/bin/nvim"
    abbr -a nvlazy "NVIM_APPNAME=nvim-lazy $NEOVIM_HOME/bin/nvim"
    abbr -a lazyvim "NVIM_APPNAME=nvim-lazy $NEOVIM_HOME/bin/nvim"
end

### tmux
abbr -a tnew 'tmux new -s' # Create a new tmux session
abbr -a tkill 'tmux kill-session -t' # Kill a tmux session
abbr -a tkill-all 'tmux list-sessions | awk -F: \'{print $1}\' | xargs -I {} tmux kill-session -t "{}"'
abbr -a tbtop "bash $HOME/.config/tmux/templates/btop.sh"
abbr -a twiki "bash $HOME/.config/tmux/templates/wiki.sh"
abbr -a tcap "tmux capture-pane -ep -t %"
abbr -a tdetach 'tmux detach' # Detach from the session
abbr -a tattach 'tmux attach -t' # Attach to a session
abbr -a tdetach-others 'tmux detach -a' # Detach other clients from the session

### misc
alias ghc-ora="node $HOME/.config/ora/cli/http.mjs"
alias reset-gpg-agent='gpgconf --kill gpg-agent'
alias start-pfctl='sudo pfctl -ef /etc/pf.conf'
abbr -a ghc-clock 'tty-clock -DSbcnrs -C5'
abbr -a ghc-ports 'netstat -tulanp'
abbr -a ghc-today 'cal -C3'
abbr -a ghc-update 'git -C ~/.config/kit pull origin kit && kit-repo sync'
