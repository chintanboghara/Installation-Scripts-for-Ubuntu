#!/bin/bash

# Script to install Rust on Ubuntu
# Does not require sudo as rustup installs to user directory

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
RUSTUP_INIT_URL="https://sh.rustup.rs"
RUST_TOOLCHAIN="stable"  # Options: "stable", "beta", "nightly", or specific version like "1.75.0"

# Function to print status messages
print_status() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}[!] Error: $1${NC}"
    exit 1
}

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_status "Detected Ubuntu version: $UBUNTU_VERSION"

# Install prerequisites
print_status "Installing prerequisites..."
sudo apt-get update -y || print_error "Failed to update package lists"
sudo apt-get install -y \
    curl \
    build-essential \
    gcc \
    make || print_error "Failed to install prerequisites"

# Download and install rustup
print_status "Downloading and installing rustup..."
curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_INIT_URL" -o /tmp/rustup-init.sh || \
    print_error "Failed to download rustup installer"
chmod +x /tmp/rustup-init.sh || print_error "Failed to make rustup installer executable"

# Run rustup installer non-interactively
print_status "Installing Rust toolchain: $RUST_TOOLCHAIN..."
/tmp/rustup-init.sh -y --default-toolchain "$RUST_TOOLCHAIN" || \
    print_error "Failed to install Rust via rustup"
rm /tmp/rustup-init.sh

# Source Rust environment to make it available in this session
print_status "Sourcing Rust environment..."
source "$HOME/.cargo/env" || print_error "Failed to source Rust environment"

# Verify installation
print_status "Verifying Rust installation..."
if command -v rustc >/dev/null 2>&1; then
    RUSTC_VERSION=$(rustc --version)
    CARGO_VERSION=$(cargo --version)
    print_status "Rust compiler: $RUSTC_VERSION"
    print_status "Cargo: $CARGO_VERSION"
    print_success "Rust installed successfully!"
else
    print_error "Rust installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
sudo apt-get clean || print_error "Failed to clean apt cache"

# Ensure Rust environment persists in future sessions
print_status "Ensuring Rust environment in shell config..."
if ! grep -q ".cargo/env" "$HOME/.bashrc"; then
    echo "source \$HOME/.cargo/env" >> "$HOME/.bashrc"
    print_success "Added Rust environment to .bashrc"
else
    print_status "Rust environment already in .bashrc"
fi

print_success "Rust installation completed successfully!"
echo -e "${BLUE}Rust Setup Information:${NC}"
echo "1. Check Rust version: rustc --version"
echo "2. Check Cargo version: cargo --version"
echo "3. Create new project: cargo new <project-name>"
echo "4. Update Rust: rustup update"
echo "5. Switch toolchain: rustup default <toolchain> (e.g., nightly)"
echo "6. Reload shell: source ~/.bashrc or log out/in to ensure PATH is updated"
echo "7. Documentation: https://www.rust-lang.org/learn"
