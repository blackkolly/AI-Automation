#!/bin/bash

echo "🔍 Installing Jaeger Distributed Tracing System..."

# Install Jaeger Operator
echo "Installing Jaeger Operator..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability

# Wait for operator to be ready
echo "Waiting for Jaeger Operator to be ready..."
kubectl wait --for=condition=available deployment/jaeger-operator -n observability --timeout=300s

# Create Jaeger instance
echo "Creating Jaeger instance..."
kubectl apply -f jaeger-instance.yaml

# Install OpenTelemetry Collector
echo "Installing OpenTelemetry Collector..."
kubectl apply -f otel-collector.yaml

# Install trace sampling configuration
echo "Configuring trace sampling..."
kubectl apply -f trace-sampling.yaml

# Install service monitors for Prometheus integration
echo "Installing service monitors..."
kubectl apply -f service-monitors.yaml

echo "✅ Jaeger distributed tracing installation completed!"
echo ""
echo "Access URLs:"
echo "- Jaeger UI: http://localhost:16686 (after port-forward)"
echo "- OpenTelemetry Collector: http://localhost:8888 (metrics)"
echo ""
echo "Port Forward Commands:"
echo "kubectl port-forward svc/jaeger-query 16686:16686 -n observability"
echo "kubectl port-forward svc/otel-collector 8888:8888 -n observability"
echo ""
echo "Verify installation:"
echo "kubectl get jaeger -n observability"
echo "kubectl get pods -n observability"
echo ""
echo "Application Integration:"
echo "- Use OTEL_EXPORTER_JAEGER_ENDPOINT=http://jaeger-collector:14268/api/traces"
echo "- Or use OpenTelemetry Collector endpoint: http://otel-collector:4317"
