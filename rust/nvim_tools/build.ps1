# Set the directory name of the current script
Set-Location -Path $PSScriptRoot

# Build your Rust project using Cargo release build
cargo build --release

$binDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath "../../bin"

# Check if the directory exists
if (-not (Test-Path -Path $binDirectoryPath)) {
    # Create the directory
    New-Item -Path $binDirectoryPath -ItemType Directory | Out-Null
}

# Copy the file `nvim_tools.dll` from target/release/ to lua/ and bin/ in your current directory
Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "target/release/nvim_tools.dll") -Destination (Join-Path -Path $PSScriptRoot -ChildPath "../../lua/nvim_tools.dll")
Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "target/release/nvim_tools.dll") -Destination (Join-Path -Path $PSScriptRoot -ChildPath "../../bin/win.nvim_tools.dll")

