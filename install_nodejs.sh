#!/bin/bash

# Script to install Node.js on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NODE_VERSION="lts"  # Options: "lts" or specific version like "20" (for NodeSource) or "18.17.0" (for NVM)
USE_NVM="no"        # Set to "yes" to use NVM instead of NodeSource repo
NVM_VERSION="v0.39.7"  # Latest NVM version as of now, check https://github.com/nvm-sh/nvm/releases

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
    ca-certificates || print_error "Failed to install prerequisites"

if [ "$USE_NVM" = "yes" ]; then
    # Install Node.js using NVM
    print_status "Installing NVM (Node Version Manager) $NVM_VERSION..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash || \
        print_error "Failed to download and install NVM"
    
    # Source NVM to make it available in this session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # Install specified Node.js version
    print_status "Installing Node.js version $NODE_VERSION via NVM..."
    nvm install "$NODE_VERSION" || print_error "Failed to install Node.js $NODE_VERSION with NVM"
    nvm use "$NODE_VERSION" || print_error "Failed to set Node.js $NODE_VERSION as active"
    nvm alias default "$NODE_VERSION" || print_error "Failed to set default Node.js version"

    # Verify NVM and Node.js installation
    print_status "Verifying NVM and Node.js installation..."
    NODE_VERSION_CHECK=$(node -v 2>/dev/null || echo "Not installed")
    NPM_VERSION_CHECK=$(npm -v 2>/dev/null || echo "Not installed")
    print_status "Node.js: $NODE_VERSION_CHECK"
    print_status "npm: $NPM_VERSION_CHECK"
    print_success "Node.js installed via NVM successfully!"
else
    # Install Node.js using NodeSource repository
    print_status "Setting up NodeSource repository for Node.js..."
    if [ "$NODE_VERSION" = "lts" ]; then
        NODE_VERSION=$(curl -sL https://deb.nodesource.com/setup_lts.x | bash - || print_error "Failed to setup NodeSource LTS repo")
    else
        curl -sL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - || \
            print_error "Failed to setup NodeSource repo for version $NODE_VERSION"
    fi

    # Install Node.js and npm
    print_status "Installing Node.js and npm..."
    apt-get install -y nodejs || print_error "Failed to install Node.js"

    # Verify Node.js and npm installation
    print_status "Verifying Node.js and npm installation..."
    NODE_VERSION_CHECK=$(node -v 2>/dev/null || echo "Not installed")
    NPM_VERSION_CHECK=$(npm -v 2>/dev/null || echo "Not installed")
    print_status "Node.js: $NODE_VERSION_CHECK"
    print_status "npm: $NPM_VERSION_CHECK"
    print_success "Node.js installed via NodeSource successfully!"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

print_success "Node.js installation completed successfully!"
echo -e "${BLUE}Node.js Setup Information:${NC}"
if [ "$USE_NVM" = "yes" ]; then
    echo "1. NVM commands:"
    echo "   - List versions: nvm ls"
    echo "   - Install new version: nvm install <version>"
    echo "   - Use version: nvm use <version>"
    echo "2. Reload shell: source ~/.bashrc or log out/in to use NVM"
else
    echo "1. Update npm (optional): npm install -g npm"
fi
echo "2. Check Node.js version: node -v"
echo "3. Check npm version: npm -v"
echo "4. Test Node.js: node -e \"console.log('Hello, Node.js!')\""
echo "5. Documentation: https://nodejs.org/en/docs/"
