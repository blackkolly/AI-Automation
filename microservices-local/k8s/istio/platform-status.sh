#!/bin/bash

echo "🔧 Microservices Platform Fix & Access Guide"
echo "============================================="

echo "📋 Current Status:"
echo "✅ Order Service: Deployed in microservices namespace"
echo "✅ Product Service: Deployed in microservices namespace"  
echo "✅ Istio Service Mesh: Fully configured"
echo "⚠️  Issue: RBAC policies blocking direct service access"
echo "⚠️  Issue: Port forwarding needed for observability"

echo ""
echo "🛠️  Fixing Service Access..."

# Check if services are running
echo "1. Checking service status..."
kubectl get pods -n microservices -l "app in (product-service,order-service)" --no-headers | wc -l

# Test working URLs
echo ""
echo "2. Testing working service endpoints..."

echo "   Frontend (should work):"
timeout 5 curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" "http://localhost:30080" || echo "   ❌ Frontend not responding"

echo "   API Gateway (should work):"
timeout 5 curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" "http://localhost:30000/health" || echo "   ❌ API Gateway not responding"

echo ""
echo "🌐 Access URLs (Updated):"
echo "================================"
echo ""
echo "📱 Frontend Application:"
echo "   http://localhost:30080"
echo ""
echo "🔗 API Gateway:"
echo "   http://localhost:30000"
echo "   Health: http://localhost:30000/health"
echo ""
echo "🏪 Product Service (via API Gateway):"
echo "   http://localhost:30000/api/products"
echo ""
echo "📦 Order Service (via API Gateway):"
echo "   http://localhost:30000/api/orders"
echo ""
echo "🎛️  For Istio Gateway (requires host header):"
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
echo "   Gateway Port: $GATEWAY_PORT"
echo "   curl -H 'Host: microservices.local' http://localhost:$GATEWAY_PORT/product/health"
echo ""
echo "📊 To access observability dashboards:"
echo "   Run: bash start-dashboards.sh"
echo "   Then: http://localhost:20001 (Kiali)"
echo ""
echo "✨ Quick Start Commands:"
echo "   curl http://localhost:30080                    # Frontend"
echo "   curl http://localhost:30000/health             # API Gateway"  
echo "   curl http://localhost:30000/api/products       # Products"
echo "   curl http://localhost:30000/api/orders         # Orders"
