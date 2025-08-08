#!/bin/bash

# Alternative Trivy Installation Methods for Windows
echo "🔐 Trivy Installation - Alternative Methods"
echo "==========================================="

# Function to download and install Trivy manually
install_trivy_manual() {
    echo "📥 Installing Trivy via direct download..."
    
    # Create local bin directory if it doesn't exist
    mkdir -p ~/bin
    
    # Set Trivy version
    TRIVY_VERSION="0.58.1"
    
    # Download Trivy for Windows
    echo "⬇️  Downloading Trivy ${TRIVY_VERSION} for Windows..."
    curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
    
    if [[ -f "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz" ]]; then
        echo "📦 Extracting Trivy..."
        tar -xzf "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
        
        # Move to local bin
        if [[ -f "trivy.exe" ]]; then
            mv trivy.exe ~/bin/
            echo "✅ Trivy installed to ~/bin/trivy.exe"
            
            # Add to PATH for current session
            export PATH="$HOME/bin:$PATH"
            
            # Clean up
            rm -f "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
            rm -f README.md LICENSE
            
            echo "🎯 Testing Trivy installation..."
            ~/bin/trivy.exe --version
            
            if [[ $? -eq 0 ]]; then
                echo "✅ Trivy installed successfully!"
                echo ""
                echo "📝 To make Trivy available in all sessions, add this to your ~/.bashrc:"
                echo "   export PATH=\"\$HOME/bin:\$PATH\""
                echo ""
                echo "🚀 You can now run: trivy.exe --help"
                return 0
            else
                echo "❌ Trivy installation verification failed"
                return 1
            fi
        else
            echo "❌ trivy.exe not found after extraction"
            return 1
        fi
    else
        echo "❌ Download failed"
        return 1
    fi
}

# Function to install via Docker (alternative method)
install_trivy_docker() {
    echo "🐳 Setting up Trivy via Docker..."
    
    if command -v docker &> /dev/null; then
        echo "✅ Docker found, pulling Trivy image..."
        docker pull aquasec/trivy:latest
        
        # Create wrapper script
        cat > ~/bin/trivy-docker.sh << 'EOF'
#!/bin/bash
# Trivy Docker wrapper script
docker run --rm -v "$PWD:/workspace" -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest "$@"
EOF
        
        chmod +x ~/bin/trivy-docker.sh
        echo "✅ Trivy Docker wrapper created: ~/bin/trivy-docker.sh"
        echo "🚀 Usage: ./trivy-docker.sh fs ."
        return 0
    else
        echo "❌ Docker not found"
        return 1
    fi
}

# Function to install via Scoop (Windows package manager)
install_trivy_scoop() {
    echo "🥄 Attempting installation via Scoop..."
    
    if command -v scoop &> /dev/null; then
        echo "✅ Scoop found, installing Trivy..."
        scoop install trivy
        
        if command -v trivy &> /dev/null; then
            echo "✅ Trivy installed via Scoop!"
            trivy --version
            return 0
        else
            echo "❌ Scoop installation failed"
            return 1
        fi
    else
        echo "⚠️  Scoop not found. To install Scoop:"
        echo "   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        echo "   irm get.scoop.sh | iex"
        return 1
    fi
}

# Function to create portable installation
create_portable_trivy() {
    echo "📱 Creating portable Trivy installation..."
    
    # Create trivy directory in current location
    mkdir -p ./trivy-portable
    cd ./trivy-portable
    
    TRIVY_VERSION="0.58.1"
    echo "⬇️  Downloading portable Trivy..."
    curl -LO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
    
    if [[ -f "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz" ]]; then
        tar -xzf "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
        rm -f "trivy_${TRIVY_VERSION}_Windows-64bit.tar.gz"
        
        # Create convenience script
        cat > trivy-scan.bat << 'EOF'
@echo off
cd /d "%~dp0"
trivy.exe %*
EOF
        
        echo "✅ Portable Trivy created in ./trivy-portable/"
        echo "🚀 Usage: cd trivy-portable && trivy.exe --help"
        echo "🚀 Or use: trivy-scan.bat --help"
        
        cd ..
        return 0
    else
        echo "❌ Portable installation failed"
        cd ..
        return 1
    fi
}

# Main installation logic
main() {
    echo "🔍 Detecting installation options..."
    echo ""
    
    # Check if running as administrator
    if net session >/dev/null 2>&1; then
        echo "✅ Running as Administrator - can try system-wide installation"
        ADMIN_MODE=true
    else
        echo "⚠️  Not running as Administrator - using user-space installation"
        ADMIN_MODE=false
    fi
    
    echo ""
    echo "📋 Available installation methods:"
    echo "1. Direct download (Recommended)"
    echo "2. Docker wrapper"
    echo "3. Scoop package manager"
    echo "4. Portable installation"
    echo ""
    
    # Try methods in order of preference
    echo "🚀 Attempting installation..."
    echo ""
    
    # Method 1: Direct download
    if install_trivy_manual; then
        echo "🎉 Installation successful via direct download!"
        exit 0
    fi
    
    echo ""
    echo "⚠️  Direct download failed, trying Docker..."
    
    # Method 2: Docker
    if install_trivy_docker; then
        echo "🎉 Docker setup successful!"
        exit 0
    fi
    
    echo ""
    echo "⚠️  Docker not available, trying Scoop..."
    
    # Method 3: Scoop
    if install_trivy_scoop; then
        echo "🎉 Scoop installation successful!"
        exit 0
    fi
    
    echo ""
    echo "⚠️  Scoop not available, creating portable installation..."
    
    # Method 4: Portable
    if create_portable_trivy; then
        echo "🎉 Portable installation created!"
        exit 0
    fi
    
    echo ""
    echo "❌ All installation methods failed."
    echo ""
    echo "📝 Manual installation instructions:"
    echo "1. Download from: https://github.com/aquasecurity/trivy/releases"
    echo "2. Extract trivy.exe to a folder in your PATH"
    echo "3. Or use the portable installation in ./trivy-portable/"
    echo ""
    echo "🐳 Alternative: Use Docker"
    echo "   docker run --rm aquasec/trivy:latest --help"
    
    exit 1
}

# Run installation
main "$@"
