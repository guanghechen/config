## Requirements

Debian or Ubuntu (including WSL), with `curl`, `sudo`, and `apt` available.

## FAQ

* **Test in docker**:

  - Build the docker image.

    ```bash
    docker build -t guanghechen/nix-remote:latest -f ~/.config/guanghechen/setup/nix-remote/Dockerfile ~/.config/guanghechen/setup/nix-remote
    ```

  - Run the docker container.

    ```bash
    docker run -it --name ghc-config guanghechen/nix-remote:latest /bin/bash
    ```

  - Run the bootstrap scripts.

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/nix-remote/setup.bash)"
    ```

  - Run the container with Bash.

    ```bash
    docker exec -it ghc-config /bin/bash
    ```

  - Remove docker container

    ```bash
    docker container stop ghc-config
    docker rm ghc-config
    ```
