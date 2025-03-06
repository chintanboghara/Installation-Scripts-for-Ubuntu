#!/bin/bash

# Script to install OWASP ZAP on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
ZAP_VERSION="2.15.0"  # Check latest at https://github.com/zaproxy/zaproxy/releases
INSTALL_DIR="/opt/zaproxy"
ZAP_USER="zap"

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

# Install prerequisites (Java 17 is required)
print_status "Installing prerequisites..."
apt-get install -y \
    openjdk-17-jre \
    wget \
    unzip || print_error "Failed to install prerequisites"

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_success "Java installed: $JAVA_VERSION"
else
    print_error "Java installation verification failed"
fi

# Create ZAP user
print_status "Creating OWASP ZAP system user..."
if ! id "$ZAP_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/false $ZAP_USER || print_error "Failed to create ZAP user"
fi

# Download and install OWASP ZAP
print_status "Downloading OWASP ZAP $ZAP_VERSION..."
cd /tmp || print_error "Cannot change to /tmp directory"
wget -q https://github.com/zaproxy/zaproxy/releases/download/v${ZAP_VERSION}/ZAP_${ZAP_VERSION}_Linux.tar.gz || \
    print_error "Failed to download OWASP ZAP"
tar -xzf ZAP_${ZAP_VERSION}_Linux.tar.gz || print_error "Failed to extract OWASP ZAP"
mv ZAP_${ZAP_VERSION} $INSTALL_DIR || print_error "Failed to move ZAP to $INSTALL_DIR"
chown -R $ZAP_USER:$ZAP_USER $INSTALL_DIR || print_error "Failed to set permissions"
rm ZAP_${ZAP_VERSION}_Linux.tar.gz

# Create symlink for easy access
print_status "Creating symlink for ZAP command..."
ln -sf $INSTALL_DIR/zap.sh /usr/local/bin/zap || print_error "Failed to create symlink"

# Create systemd service file
print_status "Creating OWASP ZAP service..."
cat << EOF > /etc/systemd/system/zap.service
[Unit]
Description=OWASP ZAP Service
After=network.target

[Service]
Type=simple
User=$ZAP_USER
ExecStart=$INSTALL_DIR/zap.sh -daemon -host 0.0.0.0 -port 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
print_status "Starting OWASP ZAP service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start zap || print_error "Failed to start ZAP service"
systemctl enable zap || print_error "Failed to enable ZAP service"

# Verify installation
print_status "Verifying OWASP ZAP installation..."
sleep 5  # Give it time to start
if systemctl is-active zap >/dev/null 2>&1; then
    ZAP_VERSION_CHECK=$($INSTALL_DIR/zap.sh -version 2>/dev/null || echo "Version check not available")
    print_success "OWASP ZAP installed and running: $ZAP_VERSION_CHECK"
else
    print_error "OWASP ZAP failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow 8080 || print_error "Failed to configure firewall"
    print_success "Opened port 8080 for OWASP ZAP"
fi

print_success "OWASP ZAP installation completed successfully!"
echo -e "${BLUE}OWASP ZAP Setup Information:${NC}"
echo "1. Access ZAP UI at: http://localhost:8080 (or your server's IP)"
echo "2. Command-line usage: 'zap -cmd' (see 'zap -h' for options)"
echo "3. Service commands:"
echo "   - Status: systemctl status zap"
echo "   - Restart: systemctl restart zap"
echo "4. Installation directory: $INSTALL_DIR"
echo "5. Logs: Check $INSTALL_DIR for log files"
