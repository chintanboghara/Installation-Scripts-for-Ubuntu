#!/bin/bash

# Script to install Grafana and Prometheus on Ubuntu
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
    wget \
    curl || print_error "Failed to install prerequisites"

# --- Prometheus Installation ---
print_status "Starting Prometheus installation..."

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

# Set up Prometheus directories and files
print_status "Setting up Prometheus directories..."
mkdir -p /etc/prometheus /var/lib/prometheus || print_error "Failed to create Prometheus directories"
mv prometheus promtool /usr/local/bin/ || print_error "Failed to move Prometheus binaries"
mv prometheus.yml /etc/prometheus/ || print_error "Failed to move Prometheus configuration"
mv consoles console_libraries /etc/prometheus/ || print_error "Failed to move Prometheus console files"
chown -R $PROMETHEUS_USER:$PROMETHEUS_USER /etc/prometheus /var/lib/prometheus || print_error "Failed to set Prometheus permissions"

# Clean up
rm -rf /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64*

# Configure Prometheus
print_status "Configuring Prometheus..."
cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT}']
EOF

# Create Prometheus systemd service
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

# Start Prometheus
print_status "Starting Prometheus service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start prometheus || print_error "Failed to start Prometheus"
systemctl enable prometheus || print_error "Failed to enable Prometheus"

# Verify Prometheus
print_status "Verifying Prometheus installation..."
sleep 5
if systemctl is-active prometheus >/dev/null 2>&1; then
    PROMETHEUS_VERSION_CHECK=$(prometheus --version 2>&1 | head -n 1)
    print_success "Prometheus installed and running: $PROMETHEUS_VERSION_CHECK"
else
    print_error "Prometheus failed to start"
fi

# --- Grafana Installation ---
print_status "Starting Grafana installation..."

# Add Grafana GPG key
print_status "Adding Grafana GPG key..."
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana-archive-keyring.gpg || \
    print_error "Failed to add Grafana GPG key"

# Add Grafana repository
print_status "Adding Grafana repository..."
echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" | \
    tee /etc/apt/sources.list.d/grafana.list > /dev/null || print_error "Failed to add Grafana repository"

# Update and install Grafana
print_status "Installing Grafana..."
apt-get update -y || print_error "Failed to update package lists with Grafana repo"
apt-get install -y grafana || print_error "Failed to install Grafana"

# Start Grafana
print_status "Starting Grafana service..."
systemctl start grafana-server || print_error "Failed to start Grafana"
systemctl enable grafana-server || print_error "Failed to enable Grafana"

# Verify Grafana
print_status "Verifying Grafana installation..."
sleep 5
if systemctl is-active grafana-server >/dev/null 2>&1; then
    GRAFANA_VERSION=$(grafana-server --version 2>/dev/null || echo "Version check not available")
    print_success "Grafana installed and running: $GRAFANA_VERSION"
else
    print_error "Grafana failed to start"
fi

# Configure Grafana to use Prometheus
print_status "Configuring Grafana basic settings..."
GRAFANA_CONF="/etc/grafana/grafana.ini"
if [ -f "$GRAFANA_CONF" ]; then
    sed -i 's/;http_port = 3000/http_port = 3000/' "$GRAFANA_CONF"
    sed -i 's/;http_addr =/http_addr = 0.0.0.0/' "$GRAFANA_CONF"
    systemctl restart grafana-server || print_error "Failed to restart Grafana"
    print_success "Updated Grafana configuration"
fi

# Firewall configuration
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow $PROMETHEUS_PORT || print_error "Failed to open Prometheus port"
    ufw allow $GRAFANA_PORT || print_error "Failed to open Grafana port"
    print_success "Opened ports $PROMETHEUS_PORT and $GRAFANA_PORT"
fi

print_success "Grafana and Prometheus installation completed successfully!"
echo -e "${BLUE}Setup Information:${NC}"
echo "1. Prometheus UI: http://localhost:${PROMETHEUS_PORT}"
echo "2. Grafana UI: http://localhost:${GRAFANA_PORT}"
echo "3. Grafana default credentials: admin/admin"
echo "4. Service commands:"
echo "   - Prometheus: systemctl [status|restart] prometheus"
echo "   - Grafana: systemctl [status|restart] grafana-server"
echo "5. Configuration files:"
echo "   - Prometheus: /etc/prometheus/prometheus.yml"
echo "   - Grafana: /etc/grafana/grafana.ini"
echo "6. Next steps:"
echo "   - Login to Grafana and add Prometheus as a data source (http://localhost:${PROMETHEUS_PORT})"
echo "   - Change Grafana admin password"
