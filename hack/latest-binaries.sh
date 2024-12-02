#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Function to check if a command exists (without sudo)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if AWS CLI is accessible (with sudo)
aws_cli_accessible() {
    sudo -n aws --version >/dev/null 2>&1
}

# Function to install AWS CLI
install_aws_cli() {
    echo "Installing unzip..."
    yum install unzip -y
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin
    rm -rf aws awscliv2.zip
    echo "AWS CLI installed successfully."
}

# Check if AWS CLI is installed and accessible, if not, install it
if ! command_exists aws || ! aws_cli_accessible; then
    echo "AWS CLI is not installed or not accessible with sudo. Installing/updating now..."
    install_aws_cli
else
    echo "AWS CLI is already installed and accessible with sudo."
fi

# Check AWS CLI version
AWS_VERSION=$(sudo aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
echo "AWS CLI version: $AWS_VERSION"

# Rest of your script
if [ "$#" -ne 1 ]; then
  echo "usage: $0 KUBERNETES_MINOR_VERSION"
  exit 1
fi

MINOR_VERSION="${1}"

# Use sudo for aws command
LATEST_BINARIES=$(sudo aws s3api list-objects-v2 --region us-west-2 --no-sign-request --bucket amazon-eks --prefix "${MINOR_VERSION}" --query 'Contents[*].[Key]' --output text | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux' | cut -d'/' -f-2 | sort -Vru | head -n1 || curl -s  "https://amazon-eks.s3.amazonaws.com/?prefix=${MINOR_VERSION}" | xmllint --format  --nocdata - | grep -E  "<Key>${MINOR_VERSION}.*[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux" | sed -E 's/.*<Key>([0-9]+\.[0-9]+\.[0-9]+\/[0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/' | sort -Vu | tail -n 1)

if [ "${LATEST_BINARIES}" == "None" ]; then
  echo >&2 "No binaries available for minor version: ${MINOR_VERSION}"
  exit 1
fi

LATEST_VERSION=$(echo "${LATEST_BINARIES}" | cut -d'/' -f1)
LATEST_BUILD_DATE=$(echo "${LATEST_BINARIES}" | cut -d'/' -f2)

echo "kubernetes_version=${LATEST_VERSION} kubernetes_build_date=${LATEST_BUILD_DATE}"
