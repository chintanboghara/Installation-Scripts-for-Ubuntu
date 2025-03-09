#!/bin/bash

# Exit the script if any command fails
set -e

# Check if the script is run with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges"
    exit 1
fi

# Update package lists to ensure we get the latest versions
echo "Updating package lists..."
apt-get update -y

# Install Python 3, pip3, development headers, and set python to point to python3
echo "Installing Python 3, pip3, and development headers..."
apt-get install -y python3 python3-pip python3-dev python-is-python3

# Clean up apt cache to save space
echo "Cleaning up..."
apt-get clean

# Verify the installations
echo "Verifying installations..."
echo "Python version:"
python3 --version
echo "pip version:"
pip3 --version

# Confirm successful completion
echo "Python installation completed successfully!"
