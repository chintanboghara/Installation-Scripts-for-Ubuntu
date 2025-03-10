#!/bin/bash

# Script to install Apache Maven on Ubuntu
# Run with sudo privileges

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
MAVEN_VERSION="3.9.9"  # Check latest at https://maven.apache.org/download.cgi
MAVEN_INSTALL_DIR="/opt/maven"
JAVA_VERSION="11"  # Maven requires Java 8+; using 11 here

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

# Install prerequisites (Java)
print_status "Installing Java $JAVA_VERSION..."
apt-get install -y openjdk-${JAVA_VERSION}-jdk || print_error "Failed to install Java"
export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64

# Verify Java installation
print_status "Verifying Java installation..."
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION_CHECK=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    print_status "Java: $JAVA_VERSION_CHECK"
else
    print_error "Java installation verification failed"
fi

# Download and install Maven
print_status "Downloading Maven $MAVEN_VERSION..."
cd /tmp || print_error "Cannot change to /tmp directory"
curl -O "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" || \
    print_error "Failed to download Maven"
tar -xzf "apache-maven-${MAVEN_VERSION}-bin.tar.gz" || print_error "Failed to extract Maven"
mkdir -p "$MAVEN_INSTALL_DIR" || print_error "Failed to create Maven install directory"
mv "apache-maven-${MAVEN_VERSION}"/* "$MAVEN_INSTALL_DIR" || print_error "Failed to move Maven files"
rm -rf "apache-maven-${MAVEN_VERSION}" "apache-maven-${MAVEN_VERSION}-bin.tar.gz"

# Set up environment variables
print_status "Configuring Maven environment variables..."
cat << EOF > /etc/profile.d/maven.sh
export JAVA_HOME=$JAVA_HOME
export MAVEN_HOME=$MAVEN_INSTALL_DIR
export PATH=\$PATH:\$MAVEN_HOME/bin
EOF
chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh || print_error "Failed to source Maven environment"

# Verify Maven installation
print_status "Verifying Maven installation..."
if command -v mvn >/dev/null 2>&1; then
    MAVEN_VERSION_CHECK=$(mvn -version 2>/dev/null | head -n 1)
    print_status "Maven: $MAVEN_VERSION_CHECK"
    print_success "Maven installed successfully!"
else
    print_error "Maven installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

# Test Maven with a simple project
print_status "Testing Maven with a sample project..."
mkdir -p /tmp/maven-test || print_error "Failed to create test directory"
cd /tmp/maven-test
mvn archetype:generate -DgroupId=com.test -DartifactId=test-app -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false -q || \
    print_error "Failed to generate Maven test project"
cd test-app
mvn package -q || print_error "Failed to build Maven test project"
rm -rf /tmp/maven-test
print_success "Maven test completed successfully"

print_success "Maven installation completed successfully!"
echo -e "${BLUE}Maven Setup Information:${NC}"
echo "1. Check Maven version: mvn -version"
echo "2. Create new project: mvn archetype:generate"
echo "3. Build a project: mvn package"
echo "4. Installation directory: $MAVEN_INSTALL_DIR"
echo "5. Environment config: /etc/profile.d/maven.sh"
echo "6. Reload shell: source /etc/profile.d/maven.sh (or log out/in)"
echo "7. Documentation: https://maven.apache.org/guides/"
