#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Enable debugging
set -x

echo "Starting script execution"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if AWS CLI is accessible
aws_cli_accessible() {
    sudo aws --version >/dev/null 2>&1
}

# Function to install AWS CLI
install_aws_cli() {
    echo "Checking if unzip is installed..."
    if ! command_exists unzip; then
        echo "unzip not found. Installing unzip..."
        sudo yum install unzip -y
        if [ $? -ne 0 ]; then
            echo "Failed to install unzip. Exiting."
            exit 1
        fi
        echo "unzip installed successfully."
    else
        echo "unzip is already installed."
    fi

    echo "Starting AWS CLI installation..."
    echo "Downloading AWS CLI..."
    if curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; then
        echo "AWS CLI download successful."
    else
        echo "Failed to download AWS CLI. Exiting."
        exit 1
    fi

    echo "Unzipping AWS CLI..."
    if unzip -q awscliv2.zip; then
        echo "AWS CLI unzipped successfully."
    else
        echo "Failed to unzip AWS CLI. Exiting."
        exit 1
    fi

    echo "Installing AWS CLI..."
    if sudo ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin; then
        echo "AWS CLI installed successfully."
    else
        echo "Failed to install AWS CLI. Exiting."
        exit 1
    fi

    

    echo "AWS CLI installation process completed."
}

# Check if AWS CLI is installed and accessible, if not, install it
echo "Checking AWS CLI installation..."
if ! command_exists aws || ! aws_cli_accessible; then
    echo "AWS CLI is not installed or not accessible. Installing/updating now..."
    install_aws_cli
else
    echo "AWS CLI is already installed and accessible."
fi

# Check AWS CLI version
echo "Checking AWS CLI version..."
if AWS_VERSION=$(sudo aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1); then
    echo "AWS CLI version: $AWS_VERSION"
else
    echo "Failed to get AWS CLI version. This might indicate a problem with the installation."
fi

# Rest of your script
if [ "$#" -ne 1 ]; then
  echo "usage: $0 KUBERNETES_MINOR_VERSION"
  exit 1
fi

MINOR_VERSION="${1}"
echo "Kubernetes minor version: $MINOR_VERSION"

# Use sudo for aws command
echo "Fetching latest binaries..."
LATEST_BINARIES=$(sudo aws s3api list-objects-v2 --region us-west-2 --no-sign-request --bucket amazon-eks --prefix "${MINOR_VERSION}" --query 'Contents[*].[Key]' --output text | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux' | cut -d'/' -f-2 | sort -Vru | head -n1 || curl -s  "https://amazon-eks.s3.amazonaws.com/?prefix=${MINOR_VERSION}" | xmllint --format  --nocdata - | grep -E  "<Key>${MINOR_VERSION}.*[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux" | sed -E 's/.*<Key>([0-9]+\.[0-9]+\.[0-9]+\/[0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/' | sort -Vu | tail -n 1)

echo "Latest binaries: $LATEST_BINARIES"

if [ "${LATEST_BINARIES}" == "None" ]; then
  echo >&2 "No binaries available for minor version: ${MINOR_VERSION}"
  exit 1
fi

LATEST_VERSION=$(echo "${LATEST_BINARIES}" | cut -d'/' -f1)
LATEST_BUILD_DATE=$(echo "${LATEST_BINARIES}" | cut -d'/' -f2)

echo "Latest Kubernetes version: $LATEST_VERSION"
echo "Latest build date: $LATEST_BUILD_DATE"

echo "kubernetes_version=${LATEST_VERSION} kubernetes_build_date=${LATEST_BUILD_DATE}"

echo "Script execution completed"
