## NeoVim

* No c compiler found! "cc", "gcc", "clang", "cl", "zig" are not executable.

  - Install mysy2.

    ```powershell
    winget install -e --source winget --id MSYS2.MSYS2
    ```

  - Start MSYS2 UCRT64 from Windows start menu, then run the following command on the prompt opened.

    1. update the package manager inside MSYS2.
    
        ```shell
        pacman -Syu
        ```
    2. Install `gcc`.

        ```shell
        pacman -S base-devel mingw-w64-x86_64-toolchain
        ```

        Choose the gcc toolchain if there are multiple options to select.

    3. Add `C:\msys64\mingw64\bin` to the system path.

