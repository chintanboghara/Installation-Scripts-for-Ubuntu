#!/bin/bash

# Script to install Apache HTTP Server on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
APACHE_PORT=80
APACHE_CONFIG_DIR="/etc/apache2"
APACHE_DEFAULT_SITE="${APACHE_CONFIG_DIR}/sites-available/000-default.conf"

# Function to print status messages
print_status() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[+] $1${NC]"
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

# Install Apache
print_status "Installing Apache..."
apt-get install -y apache2 || print_error "Failed to install Apache"

# Start and enable Apache service
print_status "Starting Apache service..."
systemctl start apache2 || print_error "Failed to start Apache"
systemctl enable apache2 || print_error "Failed to enable Apache"

# Verify Apache installation
print_status "Verifying Apache installation..."
if systemctl is-active apache2 >/dev/null 2>&1; then
    APACHE_VERSION=$(apache2 -v | head -n 1 | awk '{print $3}')
    print_status "Apache: $APACHE_VERSION"
    print_success "Apache installed and running successfully!"
else
    print_error "Apache failed to start"
fi

# Configure basic Apache settings
print_status "Configuring basic Apache settings..."
if [ -f "$APACHE_DEFAULT_SITE" ]; then
    # Backup original config
    cp "$APACHE_DEFAULT_SITE" "${APACHE_DEFAULT_SITE}.bak" || print_error "Failed to backup default config"
    
    # Update default site configuration
    cat << EOF > "$APACHE_DEFAULT_SITE"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    print_success "Updated default site configuration"
else
    print_error "Default Apache site configuration not found"
fi

# Test Apache configuration
print_status "Testing Apache configuration..."
apache2ctl configtest || print_error "Apache configuration test failed"
print_success "Apache configuration test passed"

# Reload Apache to apply changes
print_status "Reloading Apache..."
systemctl reload apache2 || print_error "Failed to reload Apache"
print_success "Apache reloaded successfully"

# Create a simple test page
print_status "Creating test HTML page..."
cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Apache</title>
</head>
<body>
    <h1>Apache Installed Successfully!</h1>
    <p>This is a test page served by Apache on Ubuntu.</p>
</body>
</html>
EOF
chown www-data:www-data /var/www/html/index.html || print_error "Failed to set test page ownership"
print_success "Test page created"

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$APACHE_PORT" || print_error "Failed to configure firewall"
    ufw allow "Apache Full" || print_error "Failed to configure Apache Full profile"
    print_success "Opened port $APACHE_PORT and Apache Full profile"
fi

print_success "Apache installation completed successfully!"
echo -e "${BLUE}Apache Setup Information:${NC}"
echo "1. Access test page: http://localhost:$APACHE_PORT (or your server's IP)"
echo "2. Service commands:"
echo "   - Status: systemctl status apache2"
echo "   - Restart: systemctl restart apache2"
echo "   - Reload: systemctl reload apache2"
echo "3. Configuration files:"
echo "   - Main config: ${APACHE_CONFIG_DIR}/apache2.conf"
echo "   - Default site: $APACHE_DEFAULT_SITE"
echo "4. Web root: /var/www/html"
echo "5. Logs:"
echo "   - Access: ${APACHE_CONFIG_DIR}/access.log"
echo "   - Error: ${APACHE_CONFIG_DIR}/error.log"
