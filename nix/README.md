* Bootstrap

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/bootstrap.sh)"
  ```

* Test in docker

  - Start a new container with ubuntu latest.
    ```bash
    docker run -it ubuntu:latest /bin/bash
    ```

  - Create a temp user with sudo privilege.

    ```bash
    apt update
    apt install -y sudo curl
    useradd -m lemon
    usermod -aG sudo lemon
    passwd lemon
    su - lemon
    ```

  - Run the bootstrap script.

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/bootstrap.sh)"
    ```
