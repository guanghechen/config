* Bootstrap

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix-remote/setup.sh)"
  ```

### FAQ

* Test in docker

  - Build the docker image.

    ```bash
    docker build -t guanghechen/nix-remote:latest -f ~/.config/guanghechen/nix-remote/Dockerfile ~/.config/guanghechen/nix-remote
    ```

  - Run the docker container.

    ```bash
    docker run -it --name ghc-config guanghechen/nix-remote:latest /bin/bash
    ```

  - Run the bootstrap scripts.

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix-remote/setup.sh)"
    ```

    Or

    ```bash
    source <(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix-remote/setup.sh)
    ```

  - Run the container with fish.

    ```bash
    docker exec -it ghc-config /home/linuxbrew/.linuxbrew/bin/fish
    ```

  - Remove docker container

    ```bash
    docker container stop ghc-config
    docker rm ghc-config
    ```
