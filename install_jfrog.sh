#!/bin/bash

# Script to install JFrog Artifactory OSS on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
JFROG_VERSION="latest"  # Set to "latest" or specific version like "7.90.10"
JFROG_HOME="/opt/jfrog"
JFROG_PORT=8081
JFROG_USER="artifactory"
DISTRO=$(lsb_release -cs)  # Automatically detect Ubuntu codename

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
    lsb-release \
    openjdk-11-jre || print_error "Failed to install prerequisites"

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_status "Java: $JAVA_VERSION"
else
    print_error "Java installation verification failed"
fi

# Add JFrog GPG key
print_status "Adding JFrog GPG key..."
curl -fsSL https://releases.jfrog.io/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/jfrog-archive-keyring.gpg || \
    print_error "Failed to add JFrog GPG key"

# Add JFrog repository
print_status "Adding JFrog Artifactory repository..."
echo "deb [signed-by=/usr/share/keyrings/jfrog-archive-keyring.gpg] https://releases.jfrog.io/artifactory/artifactory-debs $DISTRO main" | \
    tee /etc/apt/sources.list.d/jfrog-artifactory.list > /dev/null || print_error "Failed to add JFrog repository"

# Update package lists with JFrog repo
print_status "Updating package lists with JFrog repository..."
apt-get update -y || print_error "Failed to update package lists with JFrog repo"

# Install JFrog Artifactory OSS
print_status "Installing JFrog Artifactory OSS..."
if [ "$JFROG_VERSION" = "latest" ]; then
    apt-get install -y jfrog-artifactory-oss || print_error "Failed to install JFrog Artifactory OSS"
else
    apt-get install -y jfrog-artifactory-oss="$JFROG_VERSION" || print_error "Failed to install JFrog Artifactory OSS $JFROG_VERSION"
fi

# Verify JFrog installation
print_status "Verifying JFrog installation..."
if [ -d "$JFROG_HOME/artifactory" ]; then
    JFROG_VERSION_CHECK=$(/opt/jfrog/artifactory/app/bin/artifactoryctl version 2>/dev/null || echo "Not installed")
    print_status "JFrog Artifactory: $JFROG_VERSION_CHECK"
else
    print_error "JFrog installation verification failed"
fi

# Start and enable JFrog service
print_status "Starting JFrog Artifactory service..."
systemctl start artifactory || print_error "Failed to start JFrog service"
systemctl enable artifactory || print_error "Failed to enable JFrog service"

# Verify JFrog service
print_status "Verifying JFrog service..."
sleep 5  # Give it time to start
if systemctl is-active artifactory >/dev/null 2>&1; then
    print_success "JFrog Artifactory service is running"
else
    print_error "JFrog Artifactory service failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$JFROG_PORT" || print_error "Failed to open port $JFROG_PORT"
    ufw allow 8082 || print_error "Failed to open port 8082"  # For additional APIs/UI
    print_success "Opened ports $JFROG_PORT and 8082 for JFrog"
fi

print_success "JFrog Artifactory installation completed successfully!"
echo -e "${BLUE}JFrog Artifactory Setup Information:${NC}"
echo "1. Access JFrog UI: http://localhost:$JFROG_PORT (or your server's IP)"
echo "2. Default credentials: admin / password"
echo "3. Service commands:"
echo "   - Status: systemctl status artifactory"
echo "   - Restart: systemctl restart artifactory"
echo "   - Stop: systemctl stop artifactory"
echo "4. Installation directory: $JFROG_HOME/artifactory"
echo "5. Logs: /var/opt/jfrog/artifactory/log/"
echo "6. Next steps:"
echo "   - Configure via UI or $JFROG_HOME/artifactory/var/etc/system.yaml"
echo "   - Secure with SSL: See https://jfrog.com/knowledge-base/how-to-configure-ssl-for-jfrog-artifactory/"
echo "7. Documentation: https://jfrog.com/help/"
