#!/bin/bash

# Script to install Prometheus on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
PROMETHEUS_VERSION="2.51.0"  # Check latest at https://github.com/prometheus/prometheus/releases
PROMETHEUS_USER="prometheus"
PROMETHEUS_PORT=9090

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
    wget \
    curl || print_error "Failed to install prerequisites"

# Create Prometheus user
print_status "Creating Prometheus system user..."
if ! id "$PROMETHEUS_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/false $PROMETHEUS_USER || print_error "Failed to create Prometheus user"
fi

# Download and install Prometheus
print_status "Downloading Prometheus $PROMETHEUS_VERSION..."
cd /tmp || print_error "Cannot change to /tmp directory"
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz || \
    print_error "Failed to download Prometheus"
tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz || print_error "Failed to extract Prometheus"
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64 || print_error "Cannot change to Prometheus directory"

# Set up directories and move files
print_status "Setting up Prometheus directories..."
mkdir -p /etc/prometheus /var/lib/prometheus || print_error "Failed to create directories"
mv prometheus promtool /usr/local/bin/ || print_error "Failed to move binaries"
mv prometheus.yml /etc/prometheus/ || print_error "Failed to move configuration"
mv consoles console_libraries /etc/prometheus/ || print_error "Failed to move console files"
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER /etc/prometheus /var/lib/prometheus || print_error "Failed to set permissions"

# Clean up
rm -rf /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64*

# Create basic configuration
print_status "Creating basic Prometheus configuration..."
cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT}']
EOF

# Create systemd service file
print_status "Creating Prometheus service..."
cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:${PROMETHEUS_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Prometheus service
print_status "Starting Prometheus service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start prometheus || print_error "Failed to start Prometheus"
systemctl enable prometheus || print_error "Failed to enable Prometheus"

# Verify installation
print_status "Verifying Prometheus installation..."
sleep 5  # Give it time to start
if systemctl is-active prometheus >/dev/null 2>&1; then
    PROMETHEUS_VERSION_CHECK=$(prometheus --version 2>&1 | head -n 1)
    print_success "Prometheus installed and running: $PROMETHEUS_VERSION_CHECK"
else
    print_error "Prometheus failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow $PROMETHEUS_PORT || print_error "Failed to configure firewall"
    print_success "Opened port $PROMETHEUS_PORT for Prometheus"
fi

print_success "Prometheus installation completed successfully!"
echo -e "${BLUE}Prometheus Setup Information:${NC}"
echo "1. Access Prometheus at: http://localhost:${PROMETHEUS_PORT} (or your server's IP)"
echo "2. Service commands:"
echo "   - Status: systemctl status prometheus"
echo "   - Restart: systemctl restart prometheus"
echo "3. Configuration file: /etc/prometheus/prometheus.yml"
echo "4. Data directory: /var/lib/prometheus"
echo "5. Add more scrape targets in /etc/prometheus/prometheus.yml"
