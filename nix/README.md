* Bootstrap

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/bootstrap.sh)"
  ```

* Test in docker

  - Build the docker image.

    ```bash
    docker build -t guanghechen/nix:latest -f ~/.config/guanghechen/nix/Dockerfile ~/.config/guanghechen/nix
    ```

  - Run the docker container.

    ```bash
    docker run -it --name ghc-config guanghechen/nix:latest /bin/bash
    ```

  - Run the bootstrap script.

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/bootstrap.sh)"
    ```

* Install RobotoMono Nerd Font

  See https://www.nerdfonts.com/font-downloads

  ```bash
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/RobotoMono.zip
  unzip RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono /usr/share/fonts/
  sudo fc-cache -f -v
  ```
