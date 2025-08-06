# Istio Service Mesh Configuration

This directory contains comprehensive Istio service mesh configuration for the microservices platform.

## 📁 Files Overview

- `01-gateway.yaml` - Istio Gateway and Ingress Gateway configuration
- `02-virtual-services.yaml` - VirtualServices for traffic routing  
- `03-destination-rules.yaml` - DestinationRules for load balancing and circuit breaker
- `04-security-policies.yaml` - Security policies including mTLS and authorization
- `05-observability.yaml` - Observability configuration for monitoring tools
- `06-advanced-traffic.yaml` - Advanced traffic management (canary, fault injection, rate limiting)
- `install-istio.sh` - Automated installation script for Linux/macOS
- `install-istio.ps1` - Automated installation script for Windows PowerShell

## 🚀 Quick Installation

### Option 1: Automated Installation (Recommended)

**For Linux/macOS:**
```bash
# Make script executable
chmod +x install-istio.sh

# Run installation
./install-istio.sh
```

**For Windows PowerShell:**
```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install-istio.ps1
```

### Option 2: Manual Installation

#### Prerequisites
- Kubernetes cluster running (Docker Desktop or any K8s cluster)
- kubectl configured and accessible
- Internet connection for downloading Istio

#### 1. Download and Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -

# Navigate to Istio directory (version may vary)
cd istio-1.20.1

# Add istioctl to your PATH
export PATH=$PWD/bin:$PATH
```

#### 2. Install Istio Control Plane

```bash
# Install Istio with default configuration
istioctl install --set values.defaultRevision=default -y

# Verify installation
kubectl get pods -n istio-system
```

#### 3. Enable Sidecar Injection

```bash
# Label the microservices namespace for automatic sidecar injection
kubectl label namespace microservices istio-injection=enabled

# Verify the label
kubectl get namespace microservices --show-labels
```

#### 4. Install Istio Addons (Optional but Recommended)

```bash
# Install observability tools
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

# Wait for deployments to be ready
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n istio-system
```

#### 5. Apply Custom Configurations
```bash
# Check Istio system pods
kubectl get pods -n istio-system

# Check if sidecar injection is working
kubectl get pods -n microservices -o wide

# Test connectivity
istioctl proxy-status
```

## Access Points
- Kiali Dashboard: kubectl port-forward -n istio-system svc/kiali 20001:20001
- Jaeger UI: kubectl port-forward -n istio-system svc/jaeger 16686:16686
- Grafana: kubectl port-forward -n istio-system svc/grafana 3000:3000
