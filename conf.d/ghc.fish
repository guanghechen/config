# Enable vi mode
fish_vi_key_bindings

set -gx XDG_CONFIG_HOME                 "$HOME/.config"

# Set encoding
set -gx LC_CTYPE                        en_US.UTF-8
set -gx LC_ALL                          en_US.UTF-8
set -gx PYTHONIOENCODING                utf8
set -gx PYTHONUTF8                      1

# Timezone
set -gx TZ                              'Asia/Shanghai'

# Enable true color
set -gx TERM xterm-256color

# Configure environment variables
set -gx FZF_DEFAULT_COMMAND             "fd --type f"
set -gx XDG_CONFIG_HOME                 "$HOME/.config"
set -gx MYVIMRC                         "$HOME/.config/nvim/init.lua"
set -gx no_proxy                        "localhost,127.0.0.1,::1"

if test -e /proc/version
  if grep -qEi "(Microsoft|WSL)" /proc/version
    set -gx ghc_vpn_host_ip (ipconfig.exe | grep 'IPv4 Address' | awk '{print $NF}' | grep 192 | head -1 | sed 's/[^0-9.]//g')
  else
    set -gx ghc_vpn_host_ip (cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v '::' | head -1)
  end
end

# Configure PATH environment variable
fish_add_path "/usr/local/bin"
if test -f /opt/homebrew/bin/brew
    set -gx HOMEBREW_PREFIX             "/opt/homebrew"
    set -gx HOMEBREW_CELLAR             "/opt/homebrew/Cellar"
    set -gx HOMEBREW_REPOSITORY         "/opt/homebrew"
    set -gx HOMEBREW_SHELLENV_PREFIX    "/opt/homebrew"
    set -gx VIM                         "/opt/homebrew/share/nvim"
    set -gx VIMRUNTIME                  "/opt/homebrew/share/nvim/runtime"
else if test -f /home/linuxbrew/.linuxbrew/bin/brew
    set -gx HOMEBREW_PREFIX             "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_CELLAR             "/home/linuxbrew/.linuxbrew/Cellar"
    set -gx HOMEBREW_REPOSITORY         "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_SHELLENV_PREFIX    "/home/linuxbrew/.linuxbrew"
    set -gx VIM                         "/home/linuxbrew/.linuxbrew/share/nvim"
    set -gx VIMRUNTIME                  "/home/linuxbrew/.linuxbrew/share/nvim/runtime"
end
fish_add_path "$HOMEBREW_PREFIX/bin"
fish_add_path "/opt/me/bin"
fish_add_path "$HOME/.cargo/bin"
fish_add_path "$HOME/bin"

# Shortcuts for navigating directories
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias cd..='cd ../'
alias cd...='cd ../../'
alias cd....='cd ../../../'
alias cd.....='cd ../../../../'

# fzf related aliases
alias fzf="FZF_DEFAULT_OPTS_FILE=$HOME/.config/fzf/default.fzfrc $HOMEBREW_PREFIX/bin/fzf"
alias fvim='FZF_DEFAULT_OPTS_FILE=$HOME/.config/fzf/nvim.fzfrc $HOMEBREW_PREFIX/bin/fzf --print0 | xargs -0 -o nvim'

# tmux related aliases
alias tnew='tmux new -s'                # Create a new tmux session
alias tkill='tmux kill-session -t'      # Kill a tmux session
alias tkill-all='tmux list-sessions | awk \'{print $1}\' | xargs -n 1 tmux kill-session -t'
alias tdetach='tmux detach'             # Detach from the session
alias tattach='tmux attach -t'          # Attach to a session
alias takeover='tmux detach -a'         # Detach other clients from the session
alias watch-fake-clipboard="nohup bash $HOME/.config/tmux/script/fake-clipboard.sh /opt/me/data/clipboard/fake.txt &!"
alias tmux-use-fake-clipboard="tmux set-environment ghc_use_fake_clipboard /opt/me/data/clipboard/fake.txt"

# nvim related aliases
alias vim="$HOMEBREW_PREFIX/bin/nvim"
alias vi="$HOMEBREW_PREFIX/bin/nvim"
alias nvchad="NVIM_APPNAME=nvim-nvchad $HOMEBREW_PREFIX/bin/nvim"
alias lazyvim="NVIM_APPNAME=nvim-nvchad $HOMEBREW_PREFIX/bin/nvim"

# Misc
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

### Parenting changing perms on /
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'

# Others
alias ghc-ports='netstat -tulanp'
alias reset-gpg-agent='gpgconf --kill gpg-agent'
alias start-pfctl='sudo pfctl -ef /etc/pf.conf'
