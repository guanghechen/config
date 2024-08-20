# Set the directory name of the current script
Set-Location $PSScriptRoot

# Assuming cargo build is run from the root of the project, navigate there if necessary
# Navigate to the project directory where Cargo.toml is located

# Build your Rust project using Cargo release build
cargo build --release

binDirectoryPath=../../bin

# Check if the directory exists
if (-not (Test-Path -Path $binDirectoryPath)) {
    # Create the directory
    New-Item -Path $binDirectoryPath -ItemType Directory
}

# Copy the file `a.txt` from target/release/ to lua/ in your current directory
Copy-Item -Path target/release/nvim_tools.dll -Destination ../../lua/nvim_tools.dll
Copy-Item -Path target/release/nvim_tools.dll -Destination ../../bin/win.nvim_tools.dll

