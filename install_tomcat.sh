#!/bin/bash

# Script to install Apache Tomcat on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
TOMCAT_VERSION="10.1.31"  # Check latest at https://tomcat.apache.org/download-10.cgi
TOMCAT_USER="tomcat"
TOMCAT_INSTALL_DIR="/opt/tomcat"
TOMCAT_PORT=8080

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

# Install prerequisites (Java 11 required for Tomcat 10)
print_status "Installing prerequisites..."
apt-get install -y \
    openjdk-11-jre \
    curl || print_error "Failed to install prerequisites"

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_status "Java: $JAVA_VERSION"
else
    print_error "Java installation verification failed"
fi

# Create Tomcat user
print_status "Creating Tomcat system user..."
if ! id "$TOMCAT_USER" >/dev/null 2>&1; then
    useradd -r -m -s /bin/false "$TOMCAT_USER" || print_error "Failed to create Tomcat user"
fi

# Download and install Tomcat
print_status "Downloading Tomcat $TOMCAT_VERSION..."
cd /tmp || print_error "Cannot change to /tmp directory"
curl -O "https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" || \
    print_error "Failed to download Tomcat"
tar -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz" || print_error "Failed to extract Tomcat"
mkdir -p "$TOMCAT_INSTALL_DIR" || print_error "Failed to create Tomcat install directory"
mv "apache-tomcat-${TOMCAT_VERSION}"/* "$TOMCAT_INSTALL_DIR" || print_error "Failed to move Tomcat files"
chown -R "$TOMCAT_USER":"$TOMCAT_USER" "$TOMCAT_INSTALL_DIR" || print_error "Failed to set Tomcat permissions"
rm -rf "apache-tomcat-${TOMCAT_VERSION}" "apache-tomcat-${TOMCAT_VERSION}.tar.gz"

# Create systemd service file
print_status "Creating Tomcat service..."
cat << EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="CATALINA_PID=$TOMCAT_INSTALL_DIR/temp/tomcat.pid"
Environment="CATALINA_HOME=$TOMCAT_INSTALL_DIR"
Environment="CATALINA_BASE=$TOMCAT_INSTALL_DIR"
ExecStart=$TOMCAT_INSTALL_DIR/bin/startup.sh
ExecStop=$TOMCAT_INSTALL_DIR/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Tomcat
print_status "Starting Tomcat service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start tomcat || print_error "Failed to start Tomcat"
systemctl enable tomcat || print_error "Failed to enable Tomcat"

# Verify Tomcat installation
print_status "Verifying Tomcat installation..."
sleep 5  # Give it time to start
if systemctl is-active tomcat >/dev/null 2>&1; then
    print_success "Tomcat is running successfully"
else
    print_error "Tomcat failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow "$TOMCAT_PORT" || print_error "Failed to configure firewall"
    print_success "Opened port $TOMCAT_PORT for Tomcat"
fi

print_success "Tomcat installation completed successfully!"
echo -e "${BLUE}Tomcat Setup Information:${NC}"
echo "1. Access Tomcat at: http://localhost:$TOMCAT_PORT (or your server's IP)"
echo "2. Service commands:"
echo "   - Status: systemctl status tomcat"
echo "   - Restart: systemctl restart tomcat"
echo "3. Installation directory: $TOMCAT_INSTALL_DIR"
echo "4. Logs: $TOMCAT_INSTALL_DIR/logs"
echo "5. Default credentials for manager app (optional): edit $TOMCAT_INSTALL_DIR/conf/tomcat-users.xml"
