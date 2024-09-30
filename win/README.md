## Docker in wsl2

* Install the Docker Desktop follow

  - https://docs.docker.com/desktop/wsl/
  - https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers

* Install the Docker client on wsl

  - Install

    ```fish
    sudo apt-get update
    apt-cache policy docker-ce
    sudo apt-get install -y docker-ce
    sudo apt-get install docker-compose
    sudo apt-get upgrade
    ```

  - Set / or add docker group

    ```fish
    sudo usermod -a -G docker $USER
    ```

