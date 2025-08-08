# Windows-Specific Trivy Installation Guide

## 🚨 **Permission Error Solution**

The Chocolatey installation failed due to permission restrictions. Here are **alternative installation methods** that work without administrator privileges:

## 🎯 **Method 1: Direct Download (Recommended)**

### Quick Installation:
```bash
chmod +x trivy-install-windows.sh
./trivy-install-windows.sh
```

### Manual Installation:
1. **Download Trivy:**
   ```bash
   curl -LO "https://github.com/aquasecurity/trivy/releases/download/v0.58.1/trivy_0.58.1_Windows-64bit.tar.gz"
   ```

2. **Extract:**
   ```bash
   tar -xzf trivy_0.58.1_Windows-64bit.tar.gz
   ```

3. **Install to user directory:**
   ```bash
   mkdir -p ~/bin
   mv trivy.exe ~/bin/
   export PATH="$HOME/bin:$PATH"
   ```

4. **Verify:**
   ```bash
   ~/bin/trivy.exe --version
   ```

## 🐳 **Method 2: Docker (Zero Installation)**

If you have Docker installed:

```bash
# Pull Trivy image
docker pull aquasec/trivy:latest

# Scan current directory
docker run --rm -v "$PWD:/workspace" aquasec/trivy:latest fs /workspace

# Scan Docker image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image node:18-alpine

# Scan Kubernetes cluster
docker run --rm -v ~/.kube:/root/.kube aquasec/trivy:latest k8s cluster
```

## 🥄 **Method 3: Scoop Package Manager**

Install Scoop first (if not installed):
```powershell
# In PowerShell as regular user
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

Then install Trivy:
```bash
scoop install trivy
```

## 📱 **Method 4: Portable Installation**

Create a portable version:
```bash
mkdir trivy-portable
cd trivy-portable
curl -LO "https://github.com/aquasecurity/trivy/releases/download/v0.58.1/trivy_0.58.1_Windows-64bit.tar.gz"
tar -xzf trivy_0.58.1_Windows-64bit.tar.gz
./trivy.exe --version
```

## 🚀 **Quick Start After Installation**

### 1. Test Installation:
```bash
# If installed to ~/bin/
~/bin/trivy.exe --version

# If using Docker
docker run --rm aquasec/trivy:latest --version

# If using Scoop
trivy --version
```

### 2. Run First Scan:
```bash
# Scan current directory for vulnerabilities
trivy fs .

# Scan a Docker image
trivy image node:18-alpine

# Scan with specific severity
trivy fs --severity HIGH,CRITICAL .
```

### 3. Generate Reports:
```bash
# JSON report
trivy fs --format json --output report.json .

# Table report
trivy fs --format table --output report.txt .
```

## 🔧 **Troubleshooting**

### Issue: "trivy: command not found"
**Solution:** Add to PATH
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "Permission denied"
**Solution:** Use user-space installation
```bash
# Install to user directory instead of system-wide
mkdir -p ~/bin
# Move trivy.exe to ~/bin/
```

### Issue: "Docker not available"
**Solution:** Use portable installation
```bash
# Download and extract to current directory
./trivy-install-windows.sh
```

## ⚡ **Quick Commands**

Once installed, use these commands:

```bash
# Security scan current project
trivy fs --config ../trivy-config.yaml .

# Scan Kubernetes cluster
trivy k8s cluster

# Scan specific container
trivy image nginx:alpine

# Comprehensive scan with our scripts
./run-comprehensive-scan.sh
```

## 🎯 **Next Steps**

1. **Choose installation method** from above
2. **Verify installation** with `trivy --version`
3. **Run first scan** with `trivy fs .`
4. **Use our automation scripts** for comprehensive scanning

---

**Note:** The Windows-specific installer (`trivy-install-windows.sh`) automatically tries all methods and chooses the best one for your system.
