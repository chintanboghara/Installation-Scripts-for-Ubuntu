#!/bin/bash

# Script to install SonarQube on Ubuntu with PostgreSQL
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SONAR_VERSION="10.4.1.88267"  # Check latest at https://www.sonarqube.org/downloads/
SONAR_USER="sonarqube"
DB_NAME="sonarqube"
DB_USER="sonarqube"
DB_PASSWORD="sonar123"  # Change this in production!

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
    unzip \
    wget \
    openjdk-17-jre \
    postgresql \
    postgresql-contrib || print_error "Failed to install prerequisites"

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_success "Java installed: $JAVA_VERSION"
else
    print_error "Java installation verification failed"
fi

# Configure PostgreSQL
print_status "Configuring PostgreSQL..."
systemctl start postgresql || print_error "Failed to start PostgreSQL"
systemctl enable postgresql || print_error "Failed to enable PostgreSQL"

# Create database and user
print_status "Creating SonarQube database and user..."
sudo -u postgres psql <<EOF || print_error "Failed to configure PostgreSQL database"
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF
print_success "Database configured successfully"

# Create SonarQube user
print_status "Creating SonarQube system user..."
if ! id "$SONAR_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/false $SONAR_USER || print_error "Failed to create SonarQube user"
fi

# Download and install SonarQube
print_status "Downloading SonarQube $SONAR_VERSION..."
cd /opt || print_error "Cannot change to /opt directory"
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip || \
    print_error "Failed to download SonarQube"
unzip -q sonarqube-$SONAR_VERSION.zip || print_error "Failed to unzip SonarQube"
mv sonarqube-$SONAR_VERSION sonarqube || print_error "Failed to rename SonarQube directory"
rm sonarqube-$SONAR_VERSION.zip
chown -R $SONAR_USER:$SONAR_USER /opt/sonarqube || print_error "Failed to set permissions"

# Configure SonarQube
print_status "Configuring SonarQube properties..."
cat << EOF > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=$DB_USER
sonar.jdbc.password=$DB_PASSWORD
sonar.jdbc.url=jdbc:postgresql://localhost:5432/$DB_NAME
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

# Create systemd service file
print_status "Creating SonarQube service..."
cat << EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
print_status "Starting SonarQube service..."
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start sonarqube || print_error "Failed to start SonarQube"
systemctl enable sonarqube || print_error "Failed to enable SonarQube"

# Verify installation
print_status "Verifying SonarQube installation..."
sleep 10  # Give it time to start
if systemctl is-active sonarqube >/dev/null 2>&1; then
    print_success "SonarQube is running successfully"
else
    print_error "SonarQube failed to start"
fi

# Open firewall port if ufw is active
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    print_status "Configuring firewall..."
    ufw allow 9000 || print_error "Failed to configure firewall"
    print_success "Opened port 9000 for SonarQube"
fi

print_success "SonarQube installation completed successfully!"
echo -e "${BLUE}SonarQube Setup Information:${NC}"
echo "1. Access SonarQube at: http://localhost:9000 (or your server's IP)"
echo "2. Default credentials: admin/admin"
echo "3. Service commands:"
echo "   - Status: systemctl status sonarqube"
echo "   - Restart: systemctl restart sonarqube"
echo "4. Logs: /opt/sonarqube/logs"
echo "5. Change the default admin password after first login!"
