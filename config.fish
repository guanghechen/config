fish_vi_key_bindings

# Filter other users path (which could be inherit by `sudo su`)
if test (uname) = "Darwin"
  set -l current_user (whoami)
  set -l new_path
  for p in $PATH
    if not string match -q "/Users/*" -- $p || string match -q "/Users/$current_user/*" -- $p
      set new_path $new_path $p
    end
  end
  set -gx PATH $new_path
end

## Local
#
# set -gx f_vscode_settings
# set -gx f_windows_terminal_settings
#
# set -gx AZURE_OPENAI_O4_MINI_ENDPOINT     '<endpoint>'
# set -gx AZURE_OPENAI_O4_MINI_DEPLOYMENT   o4-mini
# set -gx AZURE_OPENAI_O4_MINI_MODEL        o4-mini
# set -gx AZURE_OPENAI_O4_MINI_API_KEY      <api-key>
# set -gx AZURE_OPENAI_O4_MINI_API_VERSION  2024-12-01-preview
# 
# set -gx AZURE_OPENAI_ENDPOINT     (echo $AZURE_OPENAI_O4_MINI_ENDPOINT)
# set -gx AZURE_OPENAI_DEPLOYMENT   (echo $AZURE_OPENAI_O4_MINI_DEPLOYMENT)
# set -gx AZURE_OPENAI_MODEL        (echo $AZURE_OPENAI_O4_MINI_MODEL)
# set -gx AZURE_OPENAI_API_KEY      (echo $AZURE_OPENAI_O4_MINI_API_KEY)
# set -gx AZURE_OPENAI_API_VERSION  (echo $AZURE_OPENAI_O4_MINI_API_VERSION)
# set -gx AZURE_API_BASE            (echo $AZURE_OPENAI_O4_MINI_ENDPOINT)
# set -gx AZURE_API_VERSION         (echo $AZURE_OPENAI_O4_MINI_API_VERSION)
#
# set -gx YOZORA_WORKSPACE_BLOCK
# set -gx YOZORA_WORKSPACE_NOTE
#


## setup environments
set -gx TZ                              'Asia/Shanghai'
set -gx LC_CTYPE                        en_US.UTF-8
set -gx LC_ALL                          en_US.UTF-8
set -gx LANG                            en_US.UTF-8
set -gx PYTHONIOENCODING                utf8
set -gx PYTHONUTF8                      1
set -gx XDG_CONFIG_HOME                 "$HOME/.config"
set -gx MYVIMRC                         "$HOME/.config/nvim/init.lua"
set -gx no_proxy                        "localhost,127.0.0.1,::1"

## setup paths
set -gx CONDARC                         "$HOME/.config/conda/condarc"
if test -f /opt/homebrew/bin/brew
  set -gx HOMEBREW_PREFIX               "/opt/homebrew"
  set -gx HOMEBREW_CELLAR               "/opt/homebrew/Cellar"
  set -gx HOMEBREW_REPOSITORY           "/opt/homebrew"
  set -gx HOMEBREW_SHELLENV_PREFIX      "/opt/homebrew"
  set -gx VIM                           "/opt/homebrew/share/nvim"
  set -gx VIMRUNTIME                    "/opt/homebrew/share/nvim/runtime"
else if test -f /home/linuxbrew/.linuxbrew/bin/brew
  set -gx HOMEBREW_PREFIX               "/home/linuxbrew/.linuxbrew"
  set -gx HOMEBREW_CELLAR               "/home/linuxbrew/.linuxbrew/Cellar"
  set -gx HOMEBREW_REPOSITORY           "/home/linuxbrew/.linuxbrew"
  set -gx HOMEBREW_SHELLENV_PREFIX      "/home/linuxbrew/.linuxbrew"
  set -gx VIM                           "/home/linuxbrew/.linuxbrew/share/nvim"
  set -gx VIMRUNTIME                    "/home/linuxbrew/.linuxbrew/share/nvim/runtime"
end
fish_add_path "/usr/local/bin/"
fish_add_path "$HOMEBREW_PREFIX/bin/"
fish_add_path "$HOME/.local/bin/"

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

if test -f "$HOME/.config/fish/local/config.fish"
  source "$HOME/.config/fish/local/config.fish"
end

complete -c ghc-theme-apply -a "catppuccin-latte catppuccin-mocha gruvbox-dark gruvbox-light nord one-half-dark one-half-light"
