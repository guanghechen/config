* Bootstrap

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/setup.sh)"
  ```

### FAQ

* Test in docker

  - Build the docker image.

    ```bash
    docker build -t guanghechen/nix:latest -f ~/.config/guanghechen/nix/Dockerfile ~/.config/guanghechen/nix
    ```

  - Run the docker container.

    ```bash
    docker run -it --name ghc-config guanghechen/nix:latest /bin/bash
    ```

  - Run the bootstrap scripts.

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/setup.sh)"
    ```

    Or

    ```bash
    source <(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/setup.sh)
    ```

  - Run the container with fish.

    ```bash
    docker exec -it ghc-config /home/linuxbrew/.linuxbrew/bin/fish
    ```
