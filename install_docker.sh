#!/bin/bash

# Script to install Docker on Ubuntu
# Run with sudo privileges

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
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release || print_error "Failed to install prerequisites"

# Add Docker's official GPG key
print_status "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || \
    print_error "Failed to add Docker GPG key"

# Set up the stable repository
print_status "Setting up Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null || print_error "Failed to set up Docker repository"

# Update package lists with new repository
print_status "Updating package lists with Docker repository..."
apt-get update -y || print_error "Failed to update package lists with Docker repo"

# Install Docker Engine
print_status "Installing Docker Engine..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || \
    print_error "Failed to install Docker"

# Verify Docker installation
print_status "Verifying Docker installation..."
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed successfully: $DOCKER_VERSION"
else
    print_error "Docker installation verification failed"
fi

# Add current user to docker group (non-root access)
print_status "Configuring non-root access..."
usermod -aG docker ${SUDO_USER:-$USER} || print_error "Failed to add user to docker group"
print_success "Added ${SUDO_USER:-$USER} to docker group"

# Start and enable Docker service
print_status "Starting Docker service..."
systemctl start docker || print_error "Failed to start Docker service"
systemctl enable docker || print_error "Failed to enable Docker service"

# Test Docker installation
print_status "Testing Docker installation..."
docker run --rm hello-world || print_error "Docker test run failed"
print_success "Docker test run successful"

# Install Docker Compose (standalone version)
print_status "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.6"  # Check latest version at https://github.com/docker/compose/releases
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || \
    print_error "Failed to download Docker Compose"
chmod +x /usr/local/bin/docker-compose || print_error "Failed to make Docker Compose executable"

# Verify Docker Compose installation
print_status "Verifying Docker Compose installation..."
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose installed successfully: $COMPOSE_VERSION"
else
    print_error "Docker Compose installation verification failed"
fi

print_success "Docker installation and setup completed successfully!"
echo -e "${BLUE}To get started with Docker:${NC}"
echo "1. Run containers: docker run <image>"
echo "2. List containers: docker ps -a"
echo "3. Use Compose: docker-compose up"
echo "Note: Log out and back in for group changes to take effect"
