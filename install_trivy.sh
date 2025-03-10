#!/bin/bash

# Script to install Trivy on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
TRIVY_VERSION="latest"  # Set to "latest" or specific version like "0.55.2"
INSTALL_METHOD="repo"  # Options: "repo" (default, uses APT), "binary" (downloads from GitHub)
TRIVY_INSTALL_DIR="/usr/local/bin"  # For binary install

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

# Install prerequisites
print_status "Installing prerequisites..."
apt-get install -y \
    curl \
    gnupg \
    lsb-release || print_error "Failed to install prerequisites"

if [ "$INSTALL_METHOD" = "repo" ]; then
    # Add Aqua Security GPG key
    print_status "Adding Aqua Security GPG key..."
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy-archive-keyring.gpg || \
        print_error "Failed to add Trivy GPG key"

    # Add Trivy repository
    print_status "Adding Trivy repository..."
    echo "deb [signed-by=/usr/share/keyrings/trivy-archive-keyring.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/trivy.list > /dev/null || print_error "Failed to add Trivy repository"

    # Update package lists with Trivy repo
    print_status "Updating package lists with Trivy repository..."
    apt-get update -y || print_error "Failed to update package lists with Trivy repo"

    # Install Trivy
    print_status "Installing Trivy via APT..."
    if [ "$TRIVY_VERSION" = "latest" ]; then
        apt-get install -y trivy || print_error "Failed to install Trivy"
    else
        apt-get install -y trivy="$TRIVY_VERSION" || print_error "Failed to install Trivy $TRIVY_VERSION"
    fi
else
    # Install Trivy via binary
    print_status "Installing Trivy via binary..."
    if [ "$TRIVY_VERSION" = "latest" ]; then
        TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/v//')
    fi
    curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" || \
        print_error "Failed to download Trivy binary"
    tar -xzf "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" || print_error "Failed to extract Trivy binary"
    mv trivy "$TRIVY_INSTALL_DIR/" || print_error "Failed to move Trivy to $TRIVY_INSTALL_DIR"
    chmod +x "$TRIVY_INSTALL_DIR/trivy" || print_error "Failed to make Trivy executable"
    rm "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
fi

# Verify Trivy installation
print_status "Verifying Trivy installation..."
if command -v trivy >/dev/null 2>&1; then
    TRIVY_VERSION_CHECK=$(trivy --version | grep -oP 'Version: \K.*')
    print_status "Trivy: $TRIVY_VERSION_CHECK"
    print_success "Trivy installed successfully!"
else
    print_error "Trivy installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

# Test Trivy with a simple scan
print_status "Testing Trivy with a sample scan..."
trivy image --severity CRITICAL alpine:3.18 > /tmp/trivy_test_output.txt 2>&1 || \
    print_error "Failed to run Trivy test scan"
print_success "Trivy test scan completed (output in /tmp/trivy_test_output.txt)"

print_success "Trivy installation completed successfully!"
echo -e "${BLUE}Trivy Setup Information:${NC}"
echo "1. Check Trivy version: trivy --version"
echo "2. Scan an image: trivy image <image-name>"
echo "3. Scan a filesystem: trivy fs /path/to/scan"
echo "4. Update vulnerability DB: trivy image --download-db-only"
echo "5. Test output: cat /tmp/trivy_test_output.txt"
echo "6. Documentation: https://aquasecurity.github.io/trivy/"
