## Requirements

* fnm: https://github.com/Schniz/fnm
  
  ```fish
  brew install fnm
  fnm install 20
  ```

## Proxy

* conf.d/local.fish

  - `wsl`

    ```fish
    set -gx ghc_vpn_host_ip (ipconfig.exe | grep 'IPv4 Address' | awk '{print $NF}' | grep 192 | head -1 | sed 's/[^0-9.]//g')
    set -gx ghc_vpn_host_port 1080
    ```

* conda

  ```fish
  #>>> conda initialize >>>
  # !! Contents within this block are managed by 'conda init' !!
  eval /opt/me/app/anaconda3/bin/conda "shell.fish" "hook" $argv | source
  # <<< conda initialize <<<
  ```
