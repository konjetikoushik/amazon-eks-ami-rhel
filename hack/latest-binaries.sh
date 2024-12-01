#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install AWS CLI
install_aws_cli() {
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    echo "AWS CLI installed successfully."
}

# Check if AWS CLI is installed, if not, install it
if ! command_exists aws; then
    echo "AWS CLI is not installed. Installing now..."
    install_aws_cli
else
    echo "AWS CLI is already installed."
fi

# Check AWS CLI version
AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
echo "AWS CLI version: $AWS_VERSION"

# Rest of your script
if [ "$#" -ne 1 ]; then
  echo "usage: $0 KUBERNETES_MINOR_VERSION"
  exit 1
fi

MINOR_VERSION="${1}"

# retrieve the available "VERSION/BUILD_DATE" prefixes (e.g. "1.28.1/2023-09-14")
# from the binary object keys, sorted in descending semver order, and pick the first one
# If s3api fails; use curl to pull the list.
LATEST_BINARIES=$(aws s3api list-objects-v2 --region us-west-2 --no-sign-request --bucket amazon-eks --prefix "${MINOR_VERSION}" --query 'Contents[*].[Key]' --output text | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux' | cut -d'/' -f-2 | sort -Vru | head -n1 || curl -s  "https://amazon-eks.s3.amazonaws.com/?prefix=${MINOR_VERSION}" | xmllint --format  --nocdata - | grep -E  "<Key>${MINOR_VERSION}.*[0-9]{4}-[0-9]{2}-[0-9]{2}/bin/linux" | sed -E 's/.*<Key>([0-9]+\.[0-9]+\.[0-9]+\/[0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/' | sort -Vu | tail -n 1)

if [ "${LATEST_BINARIES}" == "None" ]; then
  echo >&2 "No binaries available for minor version: ${MINOR_VERSION}"
  exit 1
fi

LATEST_VERSION=$(echo "${LATEST_BINARIES}" | cut -d'/' -f1)
LATEST_BUILD_DATE=$(echo "${LATEST_BINARIES}" | cut -d'/' -f2)

echo "kubernetes_version=${LATEST_VERSION} kubernetes_build_date=${LATEST_BUILD_DATE}"
