#!/bin/bash

# Script to install Google Cloud CLI (gcloud) on Ubuntu
# Run with sudo privileges for system-wide installation

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
GCLOUD_INSTALL_DIR="/usr/local/google-cloud-sdk"

# Function to print status messages
print_status() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[+] $1${NC]"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}[!] Error: $1${NC}"
    exit 1
}

# Check if script is run with sudo (recommended for system-wide install)
if [ "$EUID" -ne 0 ]; then
    print_status "Running without sudo - installing gcloud for current user only"
    GCLOUD_INSTALL_DIR="$HOME/google-cloud-sdk"
else
    print_status "Running with sudo - installing gcloud system-wide"
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
    apt-transport-https \
    ca-certificates \
    gnupg \
    curl || print_error "Failed to install prerequisites"

# Add Google Cloud SDK repository key
print_status "Adding Google Cloud SDK repository key..."
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/google-cloud-sdk-archive-keyring.gpg || \
    print_error "Failed to add Google Cloud SDK GPG key"

# Add Google Cloud SDK repository
print_status "Adding Google Cloud SDK repository..."
echo "deb [signed-by=/usr/share/keyrings/google-cloud-sdk-archive-keyring.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null || print_error "Failed to add Google Cloud SDK repository"

# Update package lists with Google Cloud SDK repo
print_status "Updating package lists with Google Cloud SDK repository..."
apt-get update -y || print_error "Failed to update package lists with Google Cloud SDK repo"

# Install Google Cloud SDK
print_status "Installing Google Cloud SDK..."
apt-get install -y google-cloud-sdk || print_error "Failed to install Google Cloud SDK"

# Verify installation
print_status "Verifying Google Cloud SDK installation..."
if command -v gcloud >/dev/null 2>&1; then
    GCLOUD_VERSION=$(gcloud version | head -n 1)
    print_success "Google Cloud SDK installed successfully: $GCLOUD_VERSION"
else
    print_error "Google Cloud SDK installation verification failed"
fi

# Initialize gcloud configuration (non-interactive setup requires login later)
print_status "Setting up basic gcloud configuration..."
if [ ! -d "$HOME/.config/gcloud" ]; then
    # Create a default config file with minimal settings
    gcloud init --skip-diagnostics --no-browser --quiet || print_status "Initial setup requires interactive login; run 'gcloud init' manually"
    print_success "Created basic gcloud configuration (login still required)"
else
    print_status "gcloud configuration directory already exists"
fi

print_success "Google Cloud SDK installation completed successfully!"
echo -e "${BLUE}Google Cloud SDK Setup Information:${NC}"
echo "1. Initialize and login: gcloud init"
echo "2. Authenticate: gcloud auth login"
echo "3. Check version: gcloud version"
echo "4. Test after login: gcloud auth list"
echo "5. Configuration directory: $HOME/.config/gcloud"
echo "6. Common commands:"
echo "   - List projects: gcloud projects list"
echo "   - Set project: gcloud config set project <project-id>"
echo "7. Documentation: https://cloud.google.com/sdk/docs/"
