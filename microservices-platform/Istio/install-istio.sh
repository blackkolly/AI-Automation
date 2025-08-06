#!/bin/bash

echo "🚀 Installing Istio Service Mesh..."

# Download and install Istio
if ! command -v istioctl &> /dev/null; then
    echo "📥 Downloading Istio..."
    curl -L https://istio.io/downloadIstio | sh -
    export PATH=$PWD/istio-*/bin:$PATH
fi

# Install Istio with demo profile
echo "🔧 Installing Istio with demo profile..."
istioctl install --set values.defaultRevision=default -y

# Enable automatic sidecar injection for microservices namespace
kubectl label namespace microservices istio-injection=enabled --overwrite
kubectl label namespace monitoring istio-injection=enabled --overwrite

# Apply Istio configurations
echo "📋 Applying Istio configurations..."
kubectl apply -f gateway.yaml
kubectl apply -f virtual-services.yaml
kubectl apply -f destination-rules.yaml
kubectl apply -f security-policies.yaml

# Install Kiali, Jaeger, and Grafana addons
echo "📊 Installing observability addons..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

# Wait for deployments
echo "⏳ Waiting for Istio components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n istio-system

# Expose services via NodePort
kubectl patch svc kiali -n istio-system -p '{"spec": {"type": "NodePort", "ports": [{"port": 20001, "nodePort": 30001, "name": "http"}]}}'
kubectl patch svc jaeger -n istio-system -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30002, "name": "http"}]}}'

echo ""
echo "✅ Istio Installation Complete!"
echo "🌐 Kiali Dashboard: http://localhost:30001"
echo "🔍 Jaeger Tracing: http://localhost:30002"
echo "📊 Grafana: http://localhost:30300"
echo ""
echo "💡 To access services through Istio Gateway:"
echo "   http://localhost:30080 (Gateway)"
echo ""
