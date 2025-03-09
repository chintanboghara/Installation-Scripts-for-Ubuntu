#!/bin/bash

# Script to install Git on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
GIT_CONFIG_DIR="$HOME/.gitconfig"

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

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script with sudo privileges"
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_status "Detected Ubuntu version: $UBUNTU_VERSION"

# Update package lists
print_status "Updating package lists..."
apt-get update -y || print_error "Failed to update package lists"

# Install Git
print_status "Installing Git..."
apt-get install -y git || print_error "Failed to install Git"

# Verify Git installation
print_status "Verifying Git installation..."
if command -v git >/dev/null 2>&1; then
    GIT_VERSION=$(git --version)
    print_status "Git: $GIT_VERSION"
    print_success "Git installed successfully!"
else
    print_error "Git installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

# Configure basic Git settings (optional, can be customized)
print_status "Setting up basic Git configuration..."
if [ ! -f "$GIT_CONFIG_DIR" ]; then
    git config --global user.name "Your Name" || print_error "Failed to set Git user name"
    git config --global user.email "your.email@example.com" || print_error "Failed to set Git user email"
    git config --global core.editor "nano" || print_error "Failed to set Git editor"
    git config --global init.defaultBranch "main" || print_error "Failed to set default branch"
    print_success "Basic Git configuration set"
    print_status "Please edit $GIT_CONFIG_DIR with your actual name and email"
else
    print_status "Git configuration file already exists at $GIT_CONFIG_DIR"
fi

# Test Git with a simple operation
print_status "Testing Git installation..."
mkdir -p /tmp/git-test || print_error "Failed to create test directory"
cd /tmp/git-test
git init -q || print_error "Failed to initialize Git repository"
echo "Hello, Git!" > README.md
git add README.md || print_error "Failed to stage file"
git commit -m "Initial commit" -q || print_error "Failed to commit"
rm -rf /tmp/git-test
print_success "Git test completed successfully"

print_success "Git installation completed successfully!"
echo -e "${BLUE}Git Setup Information:${NC}"
echo "1. Check Git version: git --version"
echo "2. View config: git config --list"
echo "3. Edit config: git config --global --edit"
echo "4. Clone a repo: git clone <url>"
echo "5. Configuration file: $GIT_CONFIG_DIR"
echo "6. Documentation: https://git-scm.com/doc"
