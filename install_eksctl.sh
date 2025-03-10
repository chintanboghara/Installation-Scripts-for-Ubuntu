#!/bin/bash

# Script to install eksctl on Ubuntu
# Run with sudo privileges for system-wide installation

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
EKSCTL_VERSION="latest"  # Set to "latest" or specific version like "0.197.0"
EKSCTL_INSTALL_DIR="/usr/local/bin"

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
    echo -e "${RED}[!] Error: $1${NC]"
    exit 1
}

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    print_status "Running without sudo - installing eksctl in user directory ($HOME/bin)"
    EKSCTL_INSTALL_DIR="$HOME/bin"
    mkdir -p "$EKSCTL_INSTALL_DIR" || print_error "Failed to create $EKSCTL_INSTALL_DIR"
else
    print_status "Running with sudo - installing eksctl system-wide"
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_status "Detected Ubuntu version: $UBUNTU_VERSION"

# Update package lists
print_status "Updating package lists..."
apt-get update -y || print_error "Failed to update package lists"

# Install prerequisites
print_status "Installing prerequisites..."
apt-get install -y \
    curl \
    tar || print_error "Failed to install prerequisites"

# Determine eksctl version if set to "latest"
if [ "$EKSCTL_VERSION" = "latest" ]; then
    EKSCTL_VERSION=$(curl -s https://api.github.com/repos/weaveworks/eksctl/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    print_status "Latest eksctl version detected: $EKSCTL_VERSION"
fi

# Download and install eksctl
print_status "Downloading eksctl $EKSCTL_VERSION..."
cd /tmp || print_error "Cannot change to /tmp directory"
curl -LO "https://github.com/weaveworks/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz" || \
    print_error "Failed to download eksctl"
tar -xzf "eksctl_Linux_amd64.tar.gz" || print_error "Failed to extract eksctl"
mv eksctl "$EKSCTL_INSTALL_DIR/" || print_error "Failed to move eksctl to $EKSCTL_INSTALL_DIR"
chmod +x "$EKSCTL_INSTALL_DIR/eksctl" || print_error "Failed to make eksctl executable"
rm "eksctl_Linux_amd64.tar.gz"

# Update PATH for user installation
if [ "$EUID" -ne 0 ]; then
    print_status "Updating PATH for user installation..."
    if ! grep -q "$EKSCTL_INSTALL_DIR" "$HOME/.bashrc"; then
        echo "export PATH=\$PATH:$EKSCTL_INSTALL_DIR" >> "$HOME/.bashrc"
        print_success "Added $EKSCTL_INSTALL_DIR to PATH in .bashrc"
    fi
    export PATH=$PATH:$EKSCTL_INSTALL_DIR
fi

# Verify eksctl installation
print_status "Verifying eksctl installation..."
if command -v eksctl >/dev/null 2>&1; then
    EKSCTL_VERSION_CHECK=$(eksctl version)
    print_status "eksctl: $EKSCTL_VERSION_CHECK"
    print_success "eksctl installed successfully!"
else
    print_error "eksctl installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

# Test eksctl with a simple command (requires AWS credentials for full functionality)
print_status "Testing eksctl with a version check..."
eksctl version > /tmp/eksctl_test_output.txt 2>&1 || print_error "Failed to run eksctl test"
print_success "eksctl test completed (output in /tmp/eksctl_test_output.txt)"

print_success "eksctl installation completed successfully!"
echo -e "${BLUE}eksctl Setup Information:${NC}"
echo "1. Check eksctl version: eksctl version"
echo "2. Configure AWS credentials: aws configure (requires AWS CLI)"
echo "3. Create an EKS cluster: eksctl create cluster --name my-cluster --region us-west-2"
echo "4. Installation directory: $EKSCTL_INSTALL_DIR"
if [ "$EUID" -ne 0 ]; then
    echo "5. Reload shell: source ~/.bashrc (or log out/in) to update PATH"
fi
echo "6. Documentation: https://eksctl.io/"
