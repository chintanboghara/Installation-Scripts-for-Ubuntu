#!/bin/bash

# Script to install Grafana on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
GRAFANA_PORT=3000

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
    software-properties-common \
    wget || print_error "Failed to install prerequisites"

# Add Grafana GPG key
print_status "Adding Grafana GPG key..."
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana-archive-keyring.gpg || \
    print_error "Failed to add Grafana GPG key"

# Add Grafana repository
print_status "Adding Grafana repository..."
echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" | \
    tee /etc/apt/sources.list.d/grafana.list > /dev/null || print_error "Failed to add Grafana repository"

# Update package lists with Grafana repository
print_status "Updating package lists with Grafana repository..."
apt-get update -y || print_error "Failed to update package lists with Grafana repo"

# Install Grafana
print_status "Installing Grafana..."
apt-get install -y grafana || print_error "Failed to install Grafana"

# Start and enable Grafana service
print_status "Starting Grafana service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start grafana-server || print_error "Failed to start Grafana service"
systemctl enable grafana-server || print_error "Failed to enable Grafana service"

# Verify Grafana installation
print_status "Verifying Grafana installation..."
sleep 5  # Give it time to start
if systemctl is-active grafana-server >/dev/null 2>&1; then
    GRAFANA_VERSION=$(grafana-server --version 2>/dev/null || echo "Version check not available")
    print_success "Grafana installed and running: $GRAFANA_VERSION"
else
    print_error "Grafana failed to start"
fi

# Configure basic settings (optional customization)
print_status "Configuring Grafana basic settings..."
GRAFANA_CONF="/etc/grafana/grafana.ini"
if [ -f "$GRAFANA_CONF" ]; then
    sed -i 's/;http_port = 3000/http_port = 3000/' "$GRAFANA_CONF"
    sed -i 's/;http_addr =/http_addr = 0.0.0.0/' "$GRAFANA_CONF"
    print_success "Updated Grafana configuration"
    systemctl restart grafana-server || print_error "Failed to restart Grafana after config update"
else
    print_error "Grafana configuration file not found"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow $GRAFANA_PORT || print_error "Failed to configure firewall"
    print_success "Opened port $GRAFANA_PORT for Grafana"
fi

print_success "Grafana installation completed successfully!"
echo -e "${BLUE}Grafana Setup Information:${NC}"
echo "1. Access Grafana at: http://localhost:$GRAFANA_PORT (or your server's IP)"
echo "2. Default credentials: admin/admin"
echo "3. Service commands:"
echo "   - Status: systemctl status grafana-server"
echo "   - Restart: systemctl restart grafana-server"
echo "4. Configuration file: /etc/grafana/grafana.ini"
echo "5. Logs: /var/log/grafana/grafana.log"
echo "6. Change the default admin password after first login!"
