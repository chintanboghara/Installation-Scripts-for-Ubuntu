#!/bin/bash

# Script to install Nginx on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NGINX_PORT=80
NGINX_CONFIG_DIR="/etc/nginx"
NGINX_DEFAULT_SITE="/etc/nginx/sites-available/default"

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

# Install Nginx
print_status "Installing Nginx..."
apt-get install -y nginx || print_error "Failed to install Nginx"

# Start and enable Nginx service
print_status "Starting Nginx service..."
systemctl start nginx || print_error "Failed to start Nginx"
systemctl enable nginx || print_error "Failed to enable Nginx"

# Verify Nginx installation
print_status "Verifying Nginx installation..."
if systemctl is-active nginx >/dev/null 2>&1; then
    NGINX_VERSION=$(nginx -v 2>&1 | awk '{print $3}')
    print_success "Nginx installed and running: $NGINX_VERSION"
else
    print_error "Nginx failed to start"
fi

# Configure basic Nginx settings
print_status "Configuring basic Nginx settings..."
if [ -f "$NGINX_DEFAULT_SITE" ]; then
    # Backup original config
    cp "$NGINX_DEFAULT_SITE" "$NGINX_DEFAULT_SITE.bak" || print_error "Failed to backup default config"
    
    # Create a simple default site configuration
    cat << EOF > "$NGINX_DEFAULT_SITE"
server {
    listen $NGINX_PORT default_server;
    listen [::]:$NGINX_PORT default_server;
    
    server_name _;
    
    root /var/www/html;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    print_success "Updated default site configuration"
else
    print_error "Default Nginx site configuration not found"
fi

# Test Nginx configuration
print_status "Testing Nginx configuration..."
nginx -t || print_error "Nginx configuration test failed"
print_success "Nginx configuration test passed"

# Reload Nginx to apply changes
print_status "Reloading Nginx..."
systemctl reload nginx || print_error "Failed to reload Nginx"
print_success "Nginx reloaded successfully"

# Create a simple test page
print_status "Creating test HTML page..."
cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Nginx</title>
</head>
<body>
    <h1>Nginx Installed Successfully!</h1>
    <p>This is a test page served by Nginx on Ubuntu.</p>
</body>
</html>
EOF
chown www-data:www-data /var/www/html/index.html
print_success "Test page created"

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow $NGINX_PORT || print_error "Failed to configure firewall"
    print_success "Opened port $NGINX_PORT for Nginx"
fi

print_success "Nginx installation completed successfully!"
echo -e "${BLUE}Nginx Setup Information:${NC}"
echo "1. Access test page: http://localhost:$NGINX_PORT (or your server's IP)"
echo "2. Service commands:"
echo "   - Status: systemctl status nginx"
echo "   - Restart: systemctl restart nginx"
echo "   - Reload: systemctl reload nginx"
echo "3. Configuration files:"
echo "   - Main config: $NGINX_CONFIG_DIR/nginx.conf"
echo "   - Default site: $NGINX_DEFAULT_SITE"
echo "4. Web root: /var/www/html"
echo "5. Logs:"
echo "   - Access: /var/log/nginx/access.log"
echo "   - Error: /var/log/nginx/error.log"
