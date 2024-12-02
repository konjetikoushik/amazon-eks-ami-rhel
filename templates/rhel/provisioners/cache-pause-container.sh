#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail
set -x  # Enable debugging

echo "Starting cache-pause-container.sh"
echo "Current PATH: $PATH"
echo "AWS CLI location: $(which aws 2>/dev/null || echo 'aws not found')"
echo "Contents of /usr/local/bin: $(ls -l /usr/local/bin)"
echo "Contents of /usr/bin: $(ls -l /usr/bin | grep aws)"

# Ensure AWS CLI is in the PATH
export PATH=$PATH:/usr/local/bin:/usr/bin

# Verify AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not found. Attempting to install..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
    rm -rf aws awscliv2.zip
    
    if ! command -v aws &> /dev/null; then
        echo "Failed to install AWS CLI. Exiting."
        exit 1
    fi
fi

echo "AWS CLI version: $(aws --version)"

echo "Starting containerd"
sudo systemctl start containerd

echo "Running cache-pause-container"
sudo cache-pause-container -i ${PAUSE_CONTAINER_IMAGE}

echo "Stopping containerd"
sudo systemctl stop containerd

echo "cache-pause-container.sh completed successfully"
