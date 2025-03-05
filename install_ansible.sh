#!/bin/bash

# Script to install Ansible on Ubuntu
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
apt-get install -y software-properties-common || print_error "Failed to install software-properties-common"

# Add Ansible PPA
print_status "Adding Ansible PPA..."
apt-add-repository -y ppa:ansible/ansible || print_error "Failed to add Ansible PPA"

# Update package lists again after adding PPA
print_status "Updating package lists with new PPA..."
apt-get update -y || print_error "Failed to update package lists with PPA"

# Install Ansible
print_status "Installing Ansible..."
apt-get install -y ansible || print_error "Failed to install Ansible"

# Verify installation
print_status "Verifying Ansible installation..."
if command -v ansible >/dev/null 2>&1; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    print_success "Ansible installed successfully: $ANSIBLE_VERSION"
else
    print_error "Ansible installation verification failed"
fi

# Create basic Ansible configuration directory if it doesn't exist
print_status "Setting up Ansible configuration directory..."
ANSIBLE_CONFIG_DIR="/etc/ansible"
if [ ! -d "$ANSIBLE_CONFIG_DIR" ]; then
    mkdir -p "$ANSIBLE_CONFIG_DIR" || print_error "Failed to create Ansible config directory"
    cat << EOF > "$ANSIBLE_CONFIG_DIR/ansible.cfg"
[defaults]
inventory = /etc/ansible/hosts
remote_user = ubuntu
host_key_checking = False
EOF
    print_success "Created basic Ansible configuration"
else
    print_status "Ansible configuration directory already exists"
fi

# Create default inventory file if it doesn't exist
print_status "Setting up default inventory file..."
ANSIBLE_HOSTS_FILE="/etc/ansible/hosts"
if [ ! -f "$ANSIBLE_HOSTS_FILE" ]; then
    echo -e "[local]\nlocalhost ansible_connection=local" > "$ANSIBLE_HOSTS_FILE" || \
        print_error "Failed to create hosts file"
    print_success "Created default inventory file"
else
    print_status "Inventory file already exists"
fi

# Test Ansible setup
print_status "Testing Ansible setup..."
ansible all -m ping || print_error "Ansible ping test failed"
print_success "Ansible ping test successful"

print_success "Ansible installation and setup completed successfully!"
echo -e "${BLUE}To get started with Ansible:${NC}"
echo "1. Edit inventory: /etc/ansible/hosts"
echo "2. Edit config: /etc/ansible/ansible.cfg"
echo "3. Run commands: ansible <group> -m <module>"
