#!/bin/bash

# Script to install Terraform on Ubuntu
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
    gnupg \
    software-properties-common \
    curl || print_error "Failed to install prerequisites"

# Add HashiCorp GPG key
print_status "Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || \
    print_error "Failed to add HashiCorp GPG key"

# Add HashiCorp repository
print_status "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list > /dev/null || print_error "Failed to add HashiCorp repository"

# Update package lists with new repository
print_status "Updating package lists with HashiCorp repository..."
apt-get update -y || print_error "Failed to update package lists with HashiCorp repo"

# Install Terraform
print_status "Installing Terraform..."
apt-get install -y terraform || print_error "Failed to install Terraform"

# Verify Terraform installation
print_status "Verifying Terraform installation..."
if command -v terraform >/dev/null 2>&1; then
    TERRAFORM_VERSION=$(terraform version | head -n 1)
    print_success "Terraform installed successfully: $TERRAFORM_VERSION"
else
    print_error "Terraform installation verification failed"
fi

# Create a basic Terraform test directory
print_status "Setting up test directory..."
TEST_DIR="$HOME/terraform-test"
if [ ! -d "$TEST_DIR" ]; then
    mkdir -p "$TEST_DIR" || print_error "Failed to create test directory"
    cd "$TEST_DIR"
    
    # Create a simple main.tf file for testing
    cat << EOF > main.tf
terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo 'Terraform test successful'"
  }
}
EOF
    print_success "Created basic Terraform test configuration"
else
    print_status "Test directory already exists"
fi

# Test Terraform installation
print_status "Testing Terraform installation..."
if [ -d "$TEST_DIR" ]; then
    cd "$TEST_DIR"
    terraform init || print_error "Terraform initialization failed"
    terraform validate || print_error "Terraform validation failed"
    print_success "Terraform test configuration validated successfully"
fi

print_success "Terraform installation and setup completed successfully!"
echo -e "${BLUE}To get started with Terraform:${NC}"
echo "1. Test the installation: cd $TEST_DIR && terraform apply"
echo "2. Check version: terraform version"
echo "3. Common commands:"
echo "   - Initialize: terraform init"
echo "   - Plan: terraform plan"
echo "   - Apply: terraform apply"
echo "4. Documentation: https://www.terraform.io/docs"
