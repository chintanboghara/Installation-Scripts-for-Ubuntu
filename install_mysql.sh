#!/bin/bash

# Script to install MySQL Server on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD="root_password"  # Change this to a secure password

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

# Install MySQL Server
print_status "Installing MySQL Server..."
apt-get install -y mysql-server || print_error "Failed to install MySQL Server"

# Start and enable MySQL service
print_status "Starting MySQL service..."
systemctl start mysql || print_error "Failed to start MySQL"
systemctl enable mysql || print_error "Failed to enable MySQL"

# Verify MySQL installation
print_status "Verifying MySQL installation..."
if systemctl is-active mysql >/dev/null 2>&1; then
    MYSQL_VERSION=$(mysql --version | awk '{print $5}' | tr -d ',')
    print_status "MySQL: $MYSQL_VERSION"
    print_success "MySQL installed and running successfully!"
else
    print_error "MySQL failed to start"
fi

# Secure MySQL installation
print_status "Securing MySQL installation..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" || \
    print_error "Failed to set root password"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF || print_error "Failed to secure MySQL"
DELETE FROM mysql.user WHERE User='';
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'$(hostname)';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
print_success "MySQL installation secured"

# Create a test database and table
print_status "Creating test database and table..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF || print_error "Failed to create test database"
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;
CREATE TABLE test_table (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50));
INSERT INTO test_table (name) VALUES ('Test Entry');
SELECT * FROM test_table;
DROP DATABASE test_db;
EOF
print_success "Test database created and verified successfully"

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$MYSQL_PORT" || print_error "Failed to configure firewall"
    print_success "Opened port $MYSQL_PORT for MySQL"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

print_success "MySQL installation completed successfully!"
echo -e "${BLUE}MySQL Setup Information:${NC}"
echo "1. Connect to MySQL: mysql -u root -p"
echo "2. Root password: $MYSQL_ROOT_PASSWORD (change it in production)"
echo "3. Service commands:"
echo "   - Status: systemctl status mysql"
echo "   - Restart: systemctl restart mysql"
echo "   - Stop: systemctl stop mysql"
echo "4. Configuration file: /etc/mysql/my.cnf"
echo "5. Data directory: /var/lib/mysql"
echo "6. Documentation: https://dev.mysql.com/doc/"
