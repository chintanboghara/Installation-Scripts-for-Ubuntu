#!/bin/bash

# Script to install Minikube on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
MINIKUBE_VERSION="latest"  # Use "latest" or specify version like "v1.33.1"
KUBECTL_VERSION="stable"   # Use "stable" or specify version like "v1.29.0"

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
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release || print_error "Failed to install prerequisites"

# Install Docker (Minikube requires a driver)
print_status "Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || \
        print_error "Failed to add Docker GPG key"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null || print_error "Failed to add Docker repository"
    apt-get update -y || print_error "Failed to update with Docker repo"
    apt-get install -y docker-ce docker-ce-cli containerd.io || print_error "Failed to install Docker"
    usermod -aG docker ${SUDO_USER:-$USER} || print_error "Failed to add user to docker group"
    systemctl enable docker || print_error "Failed to enable Docker"
    systemctl start docker || print_error "Failed to start Docker"
    print_success "Docker installed successfully"
else
    print_status "Docker already installed"
fi

# Install kubectl
print_status "Installing kubectl..."
if ! command -v kubectl >/dev/null 2>&1; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || \
        print_error "Failed to download kubectl"
    chmod +x kubectl || print_error "Failed to make kubectl executable"
    mv kubectl /usr/local/bin/ || print_error "Failed to move kubectl"
    print_success "kubectl installed successfully"
else
    print_status "kubectl already installed"
fi

# Install Minikube
print_status "Installing Minikube..."
if ! command -v minikube >/dev/null 2>&1; then
    curl -LO https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64 || \
        print_error "Failed to download Minikube"
    install minikube-linux-amd64 /usr/local/bin/minikube || print_error "Failed to install Minikube"
    rm minikube-linux-amd64
    print_success "Minikube installed successfully"
else
    print_status "Minikube already installed"
fi

# Verify installations
print_status "Verifying installations..."
DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Not installed")
KUBECTL_VERSION_CHECK=$(kubectl version --client 2>/dev/null || echo "Not installed")
MINIKUBE_VERSION_CHECK=$(minikube version 2>/dev/null | head -n 1 || echo "Not installed")
print_status "Docker: $DOCKER_VERSION"
print_status "kubectl: $KUBECTL_VERSION_CHECK"
print_status "Minikube: $MINIKUBE_VERSION_CHECK"

# Test Minikube
print_status "Testing Minikube setup..."
minikube start --driver=docker || print_error "Failed to start Minikube"
sleep 5  # Give it time to start
if minikube status >/dev/null 2>&1; then
    print_success "Minikube started successfully"
else
    print_error "Minikube failed to start"
fi

# Enable Minikube dashboard (optional)
print_status "Enabling Minikube dashboard..."
minikube addons enable dashboard >/dev/null 2>&1 || print_error "Failed to enable dashboard"
print_success "Minikube dashboard enabled"

print_success "Minikube installation completed successfully!"
echo -e "${BLUE}Minikube Setup Information:${NC}"
echo "1. Start Minikube: minikube start"
echo "2. Stop Minikube: minikube stop"
echo "3. Access dashboard: minikube dashboard"
echo "4. Check status: minikube status"
echo "5. Use kubectl: kubectl get pods -A"
echo "6. Note: Log out and back in for Docker group changes to take effect"
echo "7. Current cluster info: kubectl cluster-info"
