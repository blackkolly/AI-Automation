#!/bin/bash

# Trivy Installation Script for Windows/Linux
echo "🔐 Installing Trivy Vulnerability Scanner"
echo "========================================"

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        echo "windows"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

# Install Trivy based on OS
case $OS in
    "windows")
        echo "Installing Trivy for Windows..."
        if command -v choco &> /dev/null; then
            echo "Using Chocolatey..."
            choco install trivy
        elif command -v winget &> /dev/null; then
            echo "Using winget..."
            winget install Aquasec.Trivy
        else
            echo "Installing via direct download..."
            TRIVY_VERSION="0.58.1"
            curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
            tar -xzf "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
            mv trivy.exe /usr/local/bin/ 2>/dev/null || mv trivy.exe ~/bin/ 2>/dev/null || echo "Please add trivy.exe to your PATH"
        fi
        ;;
    "linux")
        echo "Installing Trivy for Linux..."
        if command -v apt &> /dev/null; then
            sudo apt-get update
            sudo apt-get install wget apt-transport-https gnupg lsb-release
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install trivy
        elif command -v yum &> /dev/null; then
            sudo yum install -y trivy
        else
            TRIVY_VERSION="0.58.1"
            curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
            tar -xzf "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
            sudo mv trivy /usr/local/bin/
        fi
        ;;
    "macos")
        echo "Installing Trivy for macOS..."
        if command -v brew &> /dev/null; then
            brew install trivy
        else
            TRIVY_VERSION="0.58.1"
            curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_macOS-64bit.tar.gz"
            tar -xzf "trivy_${TRIVY_VERSION}_macOS-64bit.tar.gz"
            sudo mv trivy /usr/local/bin/
        fi
        ;;
    *)
        echo "❌ Unsupported OS. Please install Trivy manually from: https://github.com/aquasecurity/trivy"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "Verifying Trivy installation..."
if command -v trivy &> /dev/null; then
    echo "✅ Trivy installed successfully!"
    trivy --version
    echo ""
    echo "🎯 Next steps:"
    echo "1. Run: ./trivy-scan.sh to scan your microservices"
    echo "2. Run: ./trivy-k8s-scan.sh to scan Kubernetes cluster"
    echo "3. Check reports in the ./reports/ directory"
else
    echo "❌ Trivy installation failed. Please install manually."
    exit 1
fi

echo ""
echo "🔐 Trivy Installation Complete!"
