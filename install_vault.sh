#!/bin/bash

# Script to install HashiCorp Vault on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
VAULT_VERSION="latest"  # Set to "latest" or specific version like "1.18.5"
VAULT_USER="vault"
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DATA_DIR="/opt/vault/data"
VAULT_PORT=8200

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
    unzip || print_error "Failed to install prerequisites"

# Add HashiCorp GPG key
print_status "Adding HashiCorp GPG key..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || \
    print_error "Failed to add HashiCorp GPG key"

# Add HashiCorp repository
print_status "Adding HashiCorp repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list > /dev/null || print_error "Failed to add HashiCorp repository"

# Update package lists with HashiCorp repo
print_status "Updating package lists with HashiCorp repository..."
apt-get update -y || print_error "Failed to update package lists with HashiCorp repo"

# Install Vault
print_status "Installing Vault..."
if [ "$VAULT_VERSION" = "latest" ]; then
    apt-get install -y vault || print_error "Failed to install Vault"
else
    apt-get install -y vault="$VAULT_VERSION" || print_error "Failed to install Vault $VAULT_VERSION"
fi

# Verify Vault installation
print_status "Verifying Vault installation..."
if command -v vault >/dev/null 2>&1; then
    VAULT_VERSION_CHECK=$(vault version)
    print_status "Vault: $VAULT_VERSION_CHECK"
else
    print_error "Vault installation verification failed"
fi

# Create Vault system user if not exists
print_status "Creating Vault system user..."
if ! id "$VAULT_USER" >/dev/null 2>&1; then
    useradd -r -m -s /bin/false "$VAULT_USER" || print_error "Failed to create Vault user"
fi

# Create Vault directories
print_status "Creating Vault directories..."
mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DATA_DIR" || print_error "Failed to create Vault directories"
chown -R "$VAULT_USER":"$VAULT_USER" "$VAULT_CONFIG_DIR" "$VAULT_DATA_DIR" || print_error "Failed to set Vault directory permissions"
chmod 700 "$VAULT_CONFIG_DIR" "$VAULT_DATA_DIR" || print_error "Failed to set Vault directory permissions"

# Configure Vault
print_status "Configuring Vault..."
cat << EOF > "$VAULT_CONFIG_DIR/vault.hcl"
ui = true
disable_mlock = true

storage "file" {
    path = "$VAULT_DATA_DIR"
}

listener "tcp" {
    address = "0.0.0.0:$VAULT_PORT"
    tls_disable = 1
}

api_addr = "http://0.0.0.0:$VAULT_PORT"
cluster_name = "vault-cluster"
EOF
chown "$VAULT_USER":"$VAULT_USER" "$VAULT_CONFIG_DIR/vault.hcl"
chmod 640 "$VAULT_CONFIG_DIR/vault.hcl"
print_success "Vault configuration file created"

# Create systemd service file
print_status "Creating Vault systemd service..."
cat << EOF > /etc/systemd/system/vault.service
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$VAULT_CONFIG_DIR/vault.hcl

[Service]
User=$VAULT_USER
Group=$VAULT_USER
ProtectSystem=full
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=$VAULT_CONFIG_DIR/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitBurst=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Vault service
print_status "Starting Vault service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start vault || print_error "Failed to start Vault"
systemctl enable vault || print_error "Failed to enable Vault"

# Verify Vault service
print_status "Verifying Vault service..."
sleep 5  # Give it time to start
if systemctl is-active vault >/dev/null 2>&1; then
    print_success "Vault service is running"
else
    print_error "Vault service failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$VAULT_PORT" || print_error "Failed to configure firewall"
    print_success "Opened port $VAULT_PORT for Vault"
fi

print_success "Vault installation completed successfully!"
echo -e "${BLUE}Vault Setup Information:${NC}"
echo "1. Access Vault UI: http://localhost:$VAULT_PORT/ui (or your server's IP)"
echo "2. Service commands:"
echo "   - Status: systemctl status vault"
echo "   - Restart: systemctl restart vault"
echo "   - Stop: systemctl stop vault"
echo "3. Configuration file: $VAULT_CONFIG_DIR/vault.hcl"
echo "4. Data directory: $VAULT_DATA_DIR"
echo "5. Next steps:"
echo "   - Initialize Vault: vault operator init"
echo "   - Unseal Vault: vault operator unseal"
echo "6. Documentation: https://www.vaultproject.io/docs/"
