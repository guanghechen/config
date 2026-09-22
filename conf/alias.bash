# Aliases

## basic
alias ll='lsd -la'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias .1='cd ../'
alias .2='cd ../../'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'
alias cd..='cd ../'
alias cd...='cd ../../'
alias cd....='cd ../../../'
alias cd.....='cd ../../../../'
gr() {
  git remote -v | awk '{print $2}' | head -1
}
alias tf='touch "$(date +%Y%m%d_%H%M%S).log"'

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
alias ports='netstat -tulanp'
alias rm='rm -i -I'
alias tls='tree --dirsfirst -aCF'
alias vdir='vdir --color=auto'

## claude code
alias ccc='claude --dangerously-skip-permissions'

## codex
alias cx0='FORCE_COLOR=1 codex -p copilot --dangerously-bypass-approvals-and-sandbox'
alias cx1='FORCE_COLOR=1 codex -p copilot-5-4 --dangerously-bypass-approvals-and-sandbox'
alias cxd='FORCE_COLOR=1 codex -p copilot-dev --dangerously-bypass-approvals-and-sandbox'
alias cxf='FORCE_COLOR=1 codex -p copilot-fast --dangerously-bypass-approvals-and-sandbox'
alias cxm='FORCE_COLOR=1 codex -p copilot-max --dangerously-bypass-approvals-and-sandbox'
alias cxa='FORCE_COLOR=1 codex -p azure --dangerously-bypass-approvals-and-sandbox'
alias cxa-5-4='FORCE_COLOR=1 codex -p azure-5-4 --dangerously-bypass-approvals-and-sandbox'
alias cxa2='FORCE_COLOR=1 codex -p azure2 --dangerously-bypass-approvals-and-sandbox'
alias cxa2-5-4='FORCE_COLOR=1 codex -p azure2-5-4 --dangerously-bypass-approvals-and-sandbox'

## gemini
alias ggg='gemini --model="gemini-3-pro-preview" --yolo'

## fzf
if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/bin/fzf" ]]; then
  alias fzf='"$HOMEBREW_PREFIX/bin/fzf"'
fi
fvim() {
  local -a files=()
  mapfile -d '' -t files < <(fzf --print0)
  [[ ${#files[@]} -gt 0 ]] || return 1
  nvim -- "${files[@]}"
}

## lazygit
if [[ -f "$HOME/.config/lazygit/local/theme.yml" ]]; then
  alias lg='lazygit -ucf "$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/local/theme.yml"'
else
  alias lg='lazygit -ucf "$HOME/.config/lazygit/config.yml"'
fi

## lst
alias lst='lsd --tree -I .git -I node_modules'

## nvim
if [[ -n "${NEOVIM_HOME:-}" && -x "$NEOVIM_HOME/bin/nvim" ]]; then
  alias vim='"$NEOVIM_HOME/bin/nvim"'
  alias vi='"$NEOVIM_HOME/bin/nvim"'
  alias nvchad='NVIM_APPNAME=nvim-nvchad  "$NEOVIM_HOME/bin/nvim"'
  alias nvlazy='NVIM_APPNAME=nvim-lazy    "$NEOVIM_HOME/bin/nvim"'
  alias lazyvim='NVIM_APPNAME=nvim-lazy   "$NEOVIM_HOME/bin/nvim"'
fi

## tmux
alias tnew='tmux new -s'           # Create a new tmux session
alias tkill='tmux kill-session -t' # Kill a tmux session
tkill-all() {
  tmux list-sessions | awk -F: '{print $1}' | xargs -I {} tmux kill-session -t {}
}
alias tbtop='bash $HOME/.config/tmux/templates/btop.sh'
alias twiki='bash $HOME/.config/tmux/templates/wiki.sh'
alias tcap='tmux capture-pane -ep -t %'
alias tdetach='tmux detach'           # Detach from the session
alias tattach='tmux attach -t'        # Attach to a session
alias tdetach-others='tmux detach -a' # Detach other clients from the session
## misc
alias ghc-ora='node $HOME/.config/ora/cli/http.mjs'
alias ghc-update='kit-repo sync'
alias reset-gpg-agent='gpgconf --kill gpg-agent'
alias start-pfctl='sudo pfctl -ef /etc/pf.conf'
alias ghc-clock='tty-clock -DSbcnrs -C5'
alias ghc-ports='netstat -tulanp'
alias ghc-today='cal -C3'

## Python server with Poetry (examples)
# Replace <server_entry> and <client_entry> before enabling these aliases.
# alias pydemo-server='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-debug='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m debugpy --listen 9527 -m uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-debug-wait='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m debugpy --listen 9527 --wait-for-client -m uvicorn <server_entry> --host localhost --port 9528'
# alias pydemo-client='PYTHONPATH="$PWD/app:$PYTHONPATH" poetry run python -m <client_entry> --server-endpoint=http://localhost:9528'
