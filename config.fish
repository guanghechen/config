fish_vi_key_bindings

## setup environments
set -gx TZ                              'Asia/Shanghai'
set -gx LC_CTYPE                        en_US.UTF-8
set -gx LC_ALL                          en_US.UTF-8
set -gx PYTHONIOENCODING                utf8
set -gx PYTHONUTF8                      1
set -gx XDG_CONFIG_HOME                 "$HOME/.config"
set -gx MYVIMRC                         "$HOME/.config/nvim/init.lua"
set -gx no_proxy                        "localhost,127.0.0.1,::1"

## setup paths
fish_add_path "$HOME/bin"
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

## setup vpn
if test -e /proc/version
  if grep -qEi "(Microsoft|WSL)" /proc/version
    if command -v ipconfig.exe > /dev/null
      set -gx ghc_vpn_host_ip (ipconfig.exe | grep 'IPv4 Address' | awk '{print $NF}' | grep 192 | head -1 | sed 's/[^0-9.]//g')
    end
  else
    set -gx ghc_vpn_host_ip (cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | grep -v '::' | head -1)
  end
else
  set -gx ghc_vpn_host_ip '127.0.0.1'
end

source ~/.config/fish/conf.d/theme.fish
source ~/.config/fish/conf.d/alias.fish
source ~/.config/fish/conf.d/app.fish
source ~/.config/fish/conf.d/fzf.fish

