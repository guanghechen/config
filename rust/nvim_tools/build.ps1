# Set the directory name of the current script
Set-Location $PSScriptRoot

# Assuming cargo build is run from the root of the project, navigate there if necessary
# Navigate to the project directory where Cargo.toml is located

# Build your Rust project using Cargo release build
cargo build --release

# Copy the file `a.txt` from target/release/ to lua/ in your current directory
Copy-Item -Path target/release/nvim_tools.dll -Destination ../../lua/

