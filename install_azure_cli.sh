#!/bin/bash

# Script to install Azure CLI on Ubuntu
# Run with sudo privileges for system-wide installation

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if script is run with sudo (recommended but not strictly required)
if [ "$EUID" -ne 0 ]; then
    print_status "Running without sudo - some features may require elevation later"
else
    print_status "Running with sudo - installing Azure CLI system-wide"
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
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release || print_error "Failed to install prerequisites"

# Add Azure CLI repository key
print_status "Adding Azure CLI repository key..."
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg || \
    print_error "Failed to add Azure CLI GPG key"

# Add Azure CLI repository
print_status "Adding Azure CLI repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/azure-cli.list > /dev/null || print_error "Failed to add Azure CLI repository"

# Update package lists with Azure CLI repo
print_status "Updating package lists with Azure CLI repository..."
apt-get update -y || print_error "Failed to update package lists with Azure CLI repo"

# Install Azure CLI
print_status "Installing Azure CLI..."
apt-get install -y azure-cli || print_error "Failed to install Azure CLI"

# Verify installation
print_status "Verifying Azure CLI installation..."
if command -v az >/dev/null 2>&1; then
    AZ_VERSION=$(az --version | head -n 1)
    print_success "Azure CLI installed successfully: $AZ_VERSION"
else
    print_error "Azure CLI installation verification failed"
fi

# Create a basic Azure config directory if it doesn't exist
print_status "Setting up Azure configuration directory..."
AZURE_CONFIG_DIR="$HOME/.azure"
if [ ! -d "$AZURE_CONFIG_DIR" ]; then
    mkdir -p "$AZURE_CONFIG_DIR" || print_error "Failed to create Azure config directory"
    cat << EOF > "$AZURE_CONFIG_DIR/config"
[core]
output = json
EOF
    print_success "Created basic Azure configuration file"
else
    print_status "Azure configuration directory already exists"
fi

# Test Azure CLI (requires login)
print_status "Azure CLI is installed but not logged in yet"
print_status "Run 'az login' to authenticate with your Azure account"

print_success "Azure CLI installation completed successfully!"
echo -e "${BLUE}Azure CLI Setup Information:${NC}"
echo "1. Login: az login"
echo "2. Check version: az --version"
echo "3. Test after login: az account show"
echo "4. Configuration file: $AZURE_CONFIG_DIR/config"
echo "5. Common commands:"
echo "   - List subscriptions: az account list"
echo "   - Set subscription: az account set --subscription <id>"
echo "6. Documentation: https://learn.microsoft.com/en-us/cli/azure/"
