#!/bin/bash

# Script to install Redis on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
REDIS_VERSION="latest"  # Set to "latest" (repo) or specific version like "7.4.1" (source)
INSTALL_METHOD="repo"   # Options: "repo" (default, Ubuntu repo), "source" (build from source)
REDIS_PORT=6379
REDIS_CONFIG_FILE="/etc/redis/redis.conf"

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

if [ "$INSTALL_METHOD" = "repo" ]; then
    # Install Redis from Ubuntu repository
    print_status "Installing Redis from Ubuntu repository..."
    apt-get install -y redis-server || print_error "Failed to install Redis"
else
    # Install prerequisites for building from source
    print_status "Installing build prerequisites..."
    apt-get install -y \
        build-essential \
        tcl \
        curl || print_error "Failed to install build prerequisites"

    # Determine Redis version if set to "latest"
    if [ "$REDIS_VERSION" = "latest" ]; then
        REDIS_VERSION=$(curl -s https://api.github.com/repos/redis/redis/releases/latest | grep -oP '"tag_name": "\K[^"]+')
        print_status "Latest Redis version detected: $REDIS_VERSION"
    fi

    # Download and build Redis from source
    print_status "Downloading and installing Redis $REDIS_VERSION from source..."
    cd /tmp || print_error "Cannot change to /tmp directory"
    curl -LO "https://github.com/redis/redis/archive/${REDIS_VERSION}.tar.gz" || \
        print_error "Failed to download Redis source"
    tar -xzf "${REDIS_VERSION}.tar.gz" || print_error "Failed to extract Redis source"
    cd "redis-${REDIS_VERSION}"
    make -j$(nproc) || print_error "Failed to build Redis"
    make install || print_error "Failed to install Redis"
    mkdir -p /etc/redis /var/redis || print_error "Failed to create Redis directories"
    cp redis.conf /etc/redis/ || print_error "Failed to copy Redis config"
    useradd -r -s /bin/false redis || true  # Ignore if user already exists
    chown redis:redis /etc/redis/redis.conf /var/redis
    chmod 640 /etc/redis/redis.conf

    # Create systemd service file for source install
    print_status "Creating Redis systemd service..."
    cat << EOF > /etc/systemd/system/redis.service
[Unit]
Description=Redis In-Memory Data Structure Store
After=network.target

[Service]
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=2755

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || print_error "Failed to reload systemd"
fi

# Configure Redis (for both methods)
print_status "Configuring Redis..."
sed -i "s/^supervised no/supervised systemd/" "$REDIS_CONFIG_FILE" || print_error "Failed to configure supervised mode"
sed -i "s/^port .*/port $REDIS_PORT/" "$REDIS_CONFIG_FILE" || print_error "Failed to set Redis port"
sed -i "s/^bind 127.0.0.1 ::1/bind 127.0.0.1/" "$REDIS_CONFIG_FILE" || print_error "Failed to set bind address"

# Start and enable Redis service
print_status "Starting Redis service..."
systemctl start redis || print_error "Failed to start Redis"
systemctl enable redis || print_error "Failed to enable Redis"

# Verify Redis installation
print_status "Verifying Redis installation..."
if systemctl is-active redis >/dev/null 2>&1; then
    REDIS_VERSION_CHECK=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
    print_status "Redis: $REDIS_VERSION_CHECK"
    print_success "Redis installed and running successfully!"
else
    print_error "Redis failed to start"
fi

# Test Redis with a simple command
print_status "Testing Redis with a ping..."
redis-cli ping > /tmp/redis_test_output.txt 2>&1 || print_error "Failed to ping Redis"
if grep -q "PONG" /tmp/redis_test_output.txt; then
    print_success "Redis test (ping) successful"
else
    print_error "Redis ping test failed"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$REDIS_PORT" || print_error "Failed to configure firewall"
    print_success "Opened port $REDIS_PORT for Redis"
fi

# Clean up
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"
rm -rf /tmp/redis-* /tmp/redis_test_output.txt

print_success "Redis installation completed successfully!"
echo -e "${BLUE}Redis Setup Information:${NC}"
echo "1. Check Redis version: redis-server --version"
echo "2. Connect to Redis: redis-cli"
echo "3. Service commands:"
echo "   - Status: systemctl status redis"
echo "   - Restart: systemctl restart redis"
echo "   - Stop: systemctl stop redis"
echo "4. Configuration file: $REDIS_CONFIG_FILE"
echo "5. Data directory: /var/lib/redis (repo) or /var/redis (source)"
echo "6. Documentation: https://redis.io/documentation"
