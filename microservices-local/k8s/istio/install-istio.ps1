# Istio Service Mesh Installation Script for Windows PowerShell
# This script installs Istio and applies all configurations for the microservices platform

param(
    [switch]$SkipDownload = $false
)

Write-Host "🚀 Starting Istio Service Mesh Installation..." -ForegroundColor Cyan

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if kubectl is available
try {
    kubectl version --client | Out-Null
    Write-Status "kubectl is available"
} catch {
    Write-Error "kubectl is not installed or not in PATH"
    exit 1
}

# Check if cluster is accessible
try {
    kubectl cluster-info | Out-Null
    Write-Status "Kubernetes cluster is accessible"
} catch {
    Write-Error "Cannot connect to Kubernetes cluster"
    exit 1
}

# Step 1: Download and install Istio
Write-Status "Step 1: Installing Istio..."

$istioVersion = "1.20.1"
$istioDir = "istio-$istioVersion"
$istioUrl = "https://github.com/istio/istio/releases/download/$istioVersion/istio-$istioVersion-win.zip"

if (-not $SkipDownload) {
    if (-not (Test-Path $istioDir)) {
        Write-Status "Downloading Istio $istioVersion..."
        
        try {
            Invoke-WebRequest -Uri $istioUrl -OutFile "istio.zip"
            Expand-Archive -Path "istio.zip" -DestinationPath "." -Force
            Remove-Item "istio.zip"
            Write-Success "Istio downloaded and extracted"
        } catch {
            Write-Error "Failed to download Istio: $_"
            exit 1
        }
    } else {
        Write-Success "Istio directory already exists"
    }
}

# Add istioctl to PATH for this session
$istioCtlPath = Join-Path (Get-Location) "$istioDir\bin\istioctl.exe"
if (Test-Path $istioCtlPath) {
    $env:PATH = "$((Get-Location)\$istioDir\bin);$env:PATH"
    Write-Success "istioctl added to PATH for this session"
} else {
    Write-Error "istioctl.exe not found at $istioCtlPath"
    exit 1
}

# Step 2: Install Istio control plane
Write-Status "Step 2: Installing Istio control plane..."

try {
    & $istioCtlPath install --set values.defaultRevision=default -y
    Write-Success "Istio control plane installed successfully"
} catch {
    Write-Error "Failed to install Istio control plane: $_"
    exit 1
}

# Step 3: Enable automatic sidecar injection
Write-Status "Step 3: Enabling automatic sidecar injection for microservices namespace..."

try {
    kubectl label namespace microservices istio-injection=enabled --overwrite
    Write-Success "Automatic sidecar injection enabled for microservices namespace"
} catch {
    Write-Warning "Failed to enable sidecar injection - namespace might not exist yet"
}

# Step 4: Install Istio addons
Write-Status "Step 4: Installing Istio addons (Kiali, Jaeger, Grafana, Prometheus)..."

$addons = @(
    "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml",
    "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml",
    "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml",
    "https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml"
)

foreach ($addon in $addons) {
    try {
        kubectl apply -f $addon
    } catch {
        Write-Warning "Failed to install addon: $addon"
    }
}

Write-Success "Istio addons installation completed"

# Step 5: Wait for Istio components to be ready
Write-Status "Step 5: Waiting for Istio components to be ready..."

$components = @(
    "deployment/istiod",
    "deployment/kiali", 
    "deployment/jaeger",
    "deployment/grafana",
    "deployment/prometheus"
)

foreach ($component in $components) {
    try {
        Write-Status "Waiting for $component..."
        kubectl wait --for=condition=available --timeout=300s $component -n istio-system
    } catch {
        Write-Warning "Timeout waiting for $component"
    }
}

Write-Success "Istio components are ready"

# Step 6: Apply custom Istio configurations
Write-Status "Step 6: Applying custom Istio configurations..."

# Create observability gateway
$observabilityGateway = @"
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: observability-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - kiali.local
    - jaeger.local
    - grafana.local
    - prometheus.local
"@

$observabilityGateway | kubectl apply -f -

# Apply configuration files
$configFiles = @(
    "01-gateway.yaml",
    "02-virtual-services.yaml", 
    "03-destination-rules.yaml",
    "04-security-policies.yaml",
    "05-observability.yaml",
    "06-advanced-traffic.yaml"
)

foreach ($configFile in $configFiles) {
    if (Test-Path $configFile) {
        Write-Status "Applying $configFile..."
        try {
            kubectl apply -f $configFile
        } catch {
            Write-Warning "Failed to apply $configFile: $_"
        }
    } else {
        Write-Warning "Configuration file not found: $configFile"
    }
}

Write-Success "All Istio configurations applied"

# Step 7: Verify installation
Write-Status "Step 7: Verifying Istio installation..."

Write-Host "`nIstio control plane status:" -ForegroundColor Yellow
kubectl get pods -n istio-system

Write-Host "`nIstio gateways:" -ForegroundColor Yellow
kubectl get gateway -A

Write-Host "`nVirtual Services:" -ForegroundColor Yellow
kubectl get virtualservice -A

Write-Host "`nDestination Rules:" -ForegroundColor Yellow
kubectl get destinationrule -A

Write-Success "Istio installation and configuration completed!"

# Step 8: Provide access information
Write-Host "`n=== Access Information ===" -ForegroundColor Cyan
Write-Host "To access the Istio components, set up port forwarding:" -ForegroundColor White
Write-Host ""
Write-Host "# Kiali Dashboard (Service Mesh Observability)" -ForegroundColor Green
Write-Host "kubectl port-forward svc/kiali 20001:20001 -n istio-system"
Write-Host "Access: http://localhost:20001"
Write-Host ""
Write-Host "# Jaeger (Distributed Tracing)" -ForegroundColor Green  
Write-Host "kubectl port-forward svc/jaeger 16686:16686 -n istio-system"
Write-Host "Access: http://localhost:16686"
Write-Host ""
Write-Host "# Grafana (Metrics Dashboard)" -ForegroundColor Green
Write-Host "kubectl port-forward svc/grafana 3000:3000 -n istio-system"
Write-Host "Access: http://localhost:3000"
Write-Host ""
Write-Host "# Prometheus (Metrics Collection)" -ForegroundColor Green
Write-Host "kubectl port-forward svc/prometheus 9090:9090 -n istio-system"
Write-Host "Access: http://localhost:9090"
Write-Host ""
Write-Host "# Main Application (API Gateway)" -ForegroundColor Green
Write-Host "kubectl port-forward svc/istio-ingressgateway 8080:80 -n istio-system"
Write-Host "Access: http://localhost:8080"
Write-Host ""

Write-Host "=== Local Development Setup ===" -ForegroundColor Yellow
Write-Host "Add these entries to your C:\Windows\System32\drivers\etc\hosts file:"
Write-Host "127.0.0.1 api.microservices.local"
Write-Host "127.0.0.1 kiali.local" 
Write-Host "127.0.0.1 jaeger.local"
Write-Host "127.0.0.1 grafana.local"
Write-Host "127.0.0.1 prometheus.local"
Write-Host ""

Write-Success "🎉 Istio Service Mesh is ready for your microservices platform!"
Write-Status "Next steps:"
Write-Host "1. Restart your microservices deployments to inject Istio sidecars"
Write-Host "2. Test traffic routing and security policies"
Write-Host "3. Monitor service mesh metrics in Kiali dashboard"
Write-Host "4. Use Jaeger for distributed tracing analysis"
