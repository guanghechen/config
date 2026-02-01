## FAQ

* **Test in podman**:

  - Build and start the docker image.

    ```bash
    mkdir local/pm
    cp nix/Dockerfile local/pm/
    podman run -it --name dotfiles --hostname dotfiles $(podman build -q local/pm)
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
    podman start dotfiles
    podman exec -it dotfiles /home/linuxbrew/.linuxbrew/bin/fish
    ```

    - Or Start and attach it.

      ```bash
      podman start -ai dotfiles
      ```

  - Remove docker container

    ```bash
    podman container stop dotfiles
    podman rm dotfiles
    ```

* **Test in docker**:

  - Build the docker image.

    ```bash
    docker build -t guanghechen/nix:latest -f ~/.config/guanghechen/nix/Dockerfile ~/.config/guanghechen/nix
    ```

  - Run the docker container.

    ```bash
    docker run -it --name dotfiles guanghechen/nix:latest /bin/bash
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
    docker exec -it dotfiles /home/linuxbrew/.linuxbrew/bin/fish
    ```

  - Remove docker container

    ```bash
    docker container stop dotfiles
    docker rm dotfiles
    ```


