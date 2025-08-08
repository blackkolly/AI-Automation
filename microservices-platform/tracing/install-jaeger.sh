#!/bin/bash

echo "🔍 Installing Jaeger Tracing..."

# Create tracing namespace
kubectl create namespace tracing --dry-run=client -o yaml | kubectl apply -f -

# Install Jaeger Operator
echo "📦 Installing Jaeger Operator..."
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n tracing

# Wait for operator to be ready
echo "⏳ Waiting for Jaeger Operator..."
kubectl wait --for=condition=available --timeout=300s deployment/jaeger-operator -n tracing

# Install Jaeger instance
echo "🚀 Installing Jaeger instance..."
kubectl apply -f jaeger-instance.yaml

# Install OpenTelemetry Collector
echo "📊 Installing OpenTelemetry Collector..."
kubectl apply -f otel-collector.yaml

# Wait for Jaeger to be ready
echo "⏳ Waiting for Jaeger to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n tracing

# Expose Jaeger UI via NodePort
kubectl patch svc jaeger-query -n tracing -p '{"spec": {"type": "NodePort", "ports": [{"port": 16686, "nodePort": 30686, "name": "http"}]}}'

echo ""
echo "✅ Jaeger Tracing Installation Complete!"
echo "🌐 Jaeger UI: http://localhost:30686"
echo "📊 OpenTelemetry Collector endpoint: http://otel-collector.tracing.svc.cluster.local:14268"
echo ""
echo "💡 To enable tracing in your applications:"
echo "   Set JAEGER_ENDPOINT=http://jaeger-collector.tracing.svc.cluster.local:14268/api/traces"
echo ""
