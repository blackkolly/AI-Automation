#!/bin/bash

# Port forwarding script for local microservices access
# This script creates port forwards for all microservices when NodePort access isn't working

echo "🚀 Setting up port forwards for microservices platform..."

# Kill any existing port forwards
echo "Stopping existing port forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true

# Wait a moment for processes to stop
sleep 2

echo "Starting port forwards..."

# Frontend (already accessible via NodePort 30080, but adding for consistency)
kubectl port-forward -n microservices service/frontend 8080:80 &
echo "✅ Frontend: http://localhost:8080"

# API Gateway
kubectl port-forward -n microservices svc/api-gateway 30000:3000 &
echo "✅ API Gateway: http://localhost:30000"

# Auth Service  
kubectl port-forward -n microservices svc/auth-service 30001:3001 &
echo "✅ Auth Service: http://localhost:30001"

# Product Service
kubectl port-forward -n microservices svc/product-service 30002:3002 &
echo "✅ Product Service: http://localhost:30002"

# Order Service
kubectl port-forward -n microservices svc/order-service 30003:3003 &
echo "✅ Order Service: http://localhost:30003"

# Monitoring services (use different ports to avoid conflicts)
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80 &
echo "✅ Grafana: http://localhost:3000 (admin/prom-operator)"

kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090 &
echo "✅ Prometheus: http://localhost:9090"

kubectl port-forward -n observability svc/jaeger-query 16686:80 &
echo "✅ Jaeger: http://localhost:16686"

echo ""
echo "🎉 All services are now accessible!"
echo "🌐 Main Frontend Dashboard: http://localhost:8080"
echo ""
echo "📊 Monitoring:"
echo "   • Grafana: http://localhost:3000"
echo "   • Prometheus: http://localhost:9090" 
echo "   • Jaeger: http://localhost:16686"
echo ""
echo "🔧 Microservices:"
echo "   • API Gateway: http://localhost:30000/health"
echo "   • Auth Service: http://localhost:30001/health"
echo "   • Product Service: http://localhost:30002/products"
echo "   • Order Service: http://localhost:30003/orders"
echo ""
echo "⚠️  Keep this terminal open to maintain the port forwards"
echo "⚠️  Press Ctrl+C to stop all port forwards"

# Wait for user interrupt
echo "Port forwards are running... Press Ctrl+C to stop"
wait
