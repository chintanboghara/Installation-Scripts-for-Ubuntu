#!/bin/bash

# Script to install AWS CLI v2 on Ubuntu
# Run with sudo privileges for system-wide installation

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
AWS_CLI_INSTALL_DIR="/usr/local/aws-cli"
AWS_CLI_VERSION="2"  # Installs latest AWS CLI v2

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
    print_status "Running without sudo - installing AWS CLI for current user only"
    AWS_CLI_INSTALL_DIR="$HOME/.aws-cli"
else
    print_status "Running with sudo - installing AWS CLI system-wide"
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
    unzip \
    curl || print_error "Failed to install prerequisites"

# Download AWS CLI v2
print_status "Downloading AWS CLI v2..."
cd /tmp || print_error "Cannot change to /tmp directory"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || \
    print_error "Failed to download AWS CLI"

# Unzip and install AWS CLI
print_status "Installing AWS CLI..."
unzip -q awscliv2.zip || print_error "Failed to unzip AWS CLI"
if [ "$EUID" -eq 0 ]; then
    ./aws/install --bin-dir /usr/local/bin --install-dir "$AWS_CLI_INSTALL_DIR" --update || \
        print_error "Failed to install AWS CLI system-wide"
else
    ./aws/install --bin-dir "$HOME/bin" --install-dir "$AWS_CLI_INSTALL_DIR" --update || \
        print_error "Failed to install AWS CLI for current user"
fi
rm -rf awscliv2.zip aws

# Verify installation
print_status "Verifying AWS CLI installation..."
if command -v aws >/dev/null 2>&1; then
    AWS_CLI_VERSION_CHECK=$(aws --version 2>&1)
    print_success "AWS CLI installed successfully: $AWS_CLI_VERSION_CHECK"
else
    print_error "AWS CLI installation verification failed"
fi

# Add AWS CLI to PATH if user install
if [ "$EUID" -ne 0 ]; then
    print_status "Updating PATH for current user..."
    if ! grep -q "$HOME/bin" "$HOME/.bashrc"; then
        echo "export PATH=\$PATH:$HOME/bin" >> "$HOME/.bashrc"
        print_success "Added $HOME/bin to PATH in .bashrc"
        print_status "Please run 'source ~/.bashrc' or log out/in to update PATH"
    fi
fi

# Create a basic AWS config directory if it doesn't exist
print_status "Setting up AWS configuration directory..."
AWS_CONFIG_DIR="$HOME/.aws"
if [ ! -d "$AWS_CONFIG_DIR" ]; then
    mkdir -p "$AWS_CONFIG_DIR" || print_error "Failed to create AWS config directory"
    cat << EOF > "$AWS_CONFIG_DIR/config"
[default]
region = us-east-1
output = json
EOF
    cat << EOF > "$AWS_CONFIG_DIR/credentials"
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
EOF
    chmod 600 "$AWS_CONFIG_DIR/config" "$AWS_CONFIG_DIR/credentials"
    print_success "Created basic AWS configuration files"
    print_status "Please edit $AWS_CONFIG_DIR/credentials with your actual AWS keys"
else
    print_status "AWS configuration directory already exists"
fi

print_success "AWS CLI installation completed successfully!"
echo -e "${BLUE}AWS CLI Setup Information:${NC}"
echo "1. Configure AWS CLI: aws configure"
echo "2. Check version: aws --version"
echo "3. Test AWS CLI: aws sts get-caller-identity (after configuration)"
echo "4. Configuration files:"
echo "   - Config: $AWS_CONFIG_DIR/config"
echo "   - Credentials: $AWS_CONFIG_DIR/credentials"
echo "5. Documentation: https://awscli.amazonaws.com/v2/documentation/api/latest/index.html"
if [ "$EUID" -ne 0 ]; then
    echo "6. Run 'source ~/.bashrc' to update PATH now"
fi
