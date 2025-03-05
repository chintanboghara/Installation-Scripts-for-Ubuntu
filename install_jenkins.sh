#!/bin/bash

# Script to install Jenkins on Ubuntu
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

# Install prerequisites (Java is required for Jenkins)
print_status "Installing prerequisites..."
apt-get install -y \
    fontconfig \
    openjdk-11-jre || print_error "Failed to install prerequisites"

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_success "Java installed: $JAVA_VERSION"
else
    print_error "Java installation verification failed"
fi

# Add Jenkins repository key
print_status "Adding Jenkins repository key..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null || print_error "Failed to add Jenkins key"

# Add Jenkins repository
print_status "Adding Jenkins repository..."
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null || print_error "Failed to add Jenkins repository"

# Update package lists with Jenkins repository
print_status "Updating package lists with Jenkins repository..."
apt-get update -y || print_error "Failed to update package lists with Jenkins repo"

# Install Jenkins
print_status "Installing Jenkins..."
apt-get install -y jenkins || print_error "Failed to install Jenkins"

# Start and enable Jenkins service
print_status "Starting Jenkins service..."
systemctl start jenkins || print_error "Failed to start Jenkins service"
systemctl enable jenkins || print_error "Failed to enable Jenkins service"

# Verify Jenkins is running
print_status "Verifying Jenkins installation..."
sleep 5  # Give Jenkins time to start
if systemctl is-active jenkins >/dev/null 2>&1; then
    JENKINS_VERSION=$(jenkins --version 2>/dev/null || echo "Version check not available")
    print_success "Jenkins installed and running: $JENKINS_VERSION"
else
    print_error "Jenkins failed to start"
fi

# Get initial admin password
print_status "Retrieving initial admin password..."
INITIAL_PASSWORD_FILE="/var/lib/jenkins/secrets/initialAdminPassword"
if [ -f "$INITIAL_PASSWORD_FILE" ]; then
    INITIAL_PASSWORD=$(cat "$INITIAL_PASSWORD_FILE")
    print_success "Initial admin password retrieved"
else
    print_error "Initial admin password file not found"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow 8080 || print_error "Failed to configure firewall"
    print_success "Opened port 8080 for Jenkins"
fi

print_success "Jenkins installation completed successfully!"
echo -e "${BLUE}Jenkins Setup Information:${NC}"
echo "1. Access Jenkins at: http://localhost:8080 (or your server's IP)"
echo "2. Initial Admin Password: $INITIAL_PASSWORD"
echo "3. Service commands:"
echo "   - Status: systemctl status jenkins"
echo "   - Restart: systemctl restart jenkins"
echo "4. Logs: /var/log/jenkins/jenkins.log"
