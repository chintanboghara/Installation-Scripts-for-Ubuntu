#!/bin/bash

# Script to install Boto3 on Ubuntu
# Run with sudo privileges for system-wide installation

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
PYTHON_VERSION="3"  # Installs Python 3.x (default from Ubuntu repos)
BOTO3_VERSION="latest"  # Set to "latest" or specific version like "1.35.38"
USE_VENV="no"  # Set to "yes" to install Boto3 in a virtual environment

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
    print_status "Running without sudo - some operations may fail if Python isn't installed"
else
    print_status "Running with sudo - installing system-wide"
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_status "Detected Ubuntu version: $UBUNTU_VERSION"

# Update package lists
print_status "Updating package lists..."
apt-get update -y || print_error "Failed to update package lists"

# Install Python and pip
print_status "Installing Python $PYTHON_VERSION and pip..."
apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-pip \
    python${PYTHON_VERSION}-dev || print_error "Failed to install Python and pip"
# Ensure python command points to python3
apt-get install -y python-is-python3 || print_error "Failed to set python to python3"

# Verify Python and pip installation
print_status "Verifying Python and pip installation..."
PYTHON_VERSION_CHECK=$(python --version 2>/dev/null || echo "Not installed")
PIP_VERSION_CHECK=$(pip3 --version 2>/dev/null || echo "Not installed")
print_status "Python: $PYTHON_VERSION_CHECK"
print_status "pip: $PIP_VERSION_CHECK"

if [ "$USE_VENV" = "yes" ]; then
    # Install virtualenv if not present
    print_status "Installing virtualenv..."
    apt-get install -y python3-venv || print_error "Failed to install virtualenv"

    # Create and activate virtual environment
    VENV_DIR="$HOME/boto3-venv"
    print_status "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR" || print_error "Failed to create virtual environment"
    source "$VENV_DIR/bin/activate" || print_error "Failed to activate virtual environment"
    print_success "Virtual environment activated"
fi

# Install Boto3
print_status "Installing Boto3..."
if [ "$BOTO3_VERSION" = "latest" ]; then
    pip3 install boto3 || print_error "Failed to install Boto3"
else
    pip3 install boto3=="$BOTO3_VERSION" || print_error "Failed to install Boto3 $BOTO3_VERSION"
fi

# Verify Boto3 installation
print_status "Verifying Boto3 installation..."
BOTO3_VERSION_CHECK=$(python3 -c "import boto3; print(boto3.__version__)" 2>/dev/null || echo "Not installed")
if [ "$BOTO3_VERSION_CHECK" != "Not installed" ]; then
    print_status "Boto3: $BOTO3_VERSION_CHECK"
    print_success "Boto3 installed successfully!"
else
    print_error "Boto3 installation verification failed"
fi

# Clean up apt cache
print_status "Cleaning up..."
apt-get clean || print_error "Failed to clean apt cache"

# Test Boto3 with a simple script (requires AWS credentials to fully work)
print_status "Creating a test script for Boto3..."
cat << EOF > /tmp/test_boto3.py
import boto3
print("Boto3 is working!")
# Uncomment and configure with credentials to test AWS connectivity
# s3 = boto3.client('s3')
# print(s3.list_buckets())
EOF
python3 /tmp/test_boto3.py || print_error "Failed to run Boto3 test script"
rm /tmp/test_boto3.py
print_success "Boto3 test script ran successfully"

print_success "Boto3 installation completed successfully!"
echo -e "${BLUE}Boto3 Setup Information:${NC}"
if [ "$USE_VENV" = "yes" ]; then
    echo "1. Activate virtual environment: source $VENV_DIR/bin/activate"
    echo "2. Deactivate: deactivate"
else
    echo "1. Boto3 is installed system-wide"
fi
echo "2. Check Boto3 version: python3 -c 'import boto3; print(boto3.__version__)'"
echo "3. Configure AWS credentials: aws configure (requires AWS CLI)"
echo "4. Test with AWS: Edit and run a script with boto3.client('s3').list_buckets()"
echo "5. Documentation: https://boto3.amazonaws.com/v1/documentation/api/latest/index.html"
