#!/bin/bash

# Script to install KinD on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
KIND_VERSION="v0.23.0"  # Check latest at https://github.com/kubernetes-sigs/kind/releases
KUBECTL_VERSION="stable" # Use "stable" or specify like "v1.29.0"

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

# Install Docker (KinD requires Docker)
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

# Install KinD
print_status "Installing KinD $KIND_VERSION..."
if ! command -v kind >/dev/null 2>&1; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64 || \
        print_error "Failed to download KinD"
    chmod +x ./kind || print_error "Failed to make KinD executable"
    mv ./kind /usr/local/bin/ || print_error "Failed to move KinD"
    print_success "KinD installed successfully"
else
    print_status "KinD already installed"
fi

# Verify installations
print_status "Verifying installations..."
DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Not installed")
KUBECTL_VERSION_CHECK=$(kubectl version --client 2>/dev/null || echo "Not installed")
KIND_VERSION_CHECK=$(kind version 2>/dev/null || echo "Not installed")
print_status "Docker: $DOCKER_VERSION"
print_status "kubectl: $KUBECTL_VERSION_CHECK"
print_status "KinD: $KIND_VERSION_CHECK"

# Create a test KinD cluster
print_status "Creating a test KinD cluster..."
cat << EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF
kind create cluster --name test-cluster --config kind-config.yaml || print_error "Failed to create KinD cluster"
rm kind-config.yaml

# Verify cluster
print_status "Verifying KinD cluster..."
if kubectl cluster-info --context kind-test-cluster >/dev/null 2>&1; then
    print_success "KinD cluster 'test-cluster' created successfully"
else
    print_error "KinD cluster verification failed"
fi

print_success "KinD installation completed successfully!"
echo -e "${BLUE}KinD Setup Information:${NC}"
echo "1. List clusters: kind get clusters"
echo "2. Delete test cluster: kind delete cluster --name test-cluster"
echo "3. Use kubectl: kubectl get nodes --context kind-test-cluster"
echo "4. Create new cluster: kind create cluster --name <name>"
echo "5. Check KinD version: kind version"
echo "6. Note: Log out and back in for Docker group changes to take effect"
echo "7. Current cluster info: kubectl cluster-info --context kind-test-cluster"
