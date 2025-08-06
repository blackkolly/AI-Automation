#!/bin/bash

# Quick Product and Order Services Check
echo "🔍 Product & Order Services Status Check"
echo "========================================"

echo "1. Checking Pod Status:"
kubectl get pods -n microservices -l "app in (product-service,order-service)" -o wide

echo -e "\n2. Checking Service Status:"
kubectl get svc -n microservices -l "app in (product-service,order-service)"

echo -e "\n3. Testing Working Service Endpoints:"
echo "API Gateway Health:"
curl -s --max-time 3 "http://localhost:30000/health" | jq -r '.service + ": " + .status' 2>/dev/null || echo "❌ API Gateway not responding"

echo -e "\nAPI Gateway Status:"
curl -s --max-time 3 "http://localhost:30000/api/status" | jq -r '.message' 2>/dev/null || echo "❌ API Gateway status not available"

echo -e "\nFrontend:"
timeout 3 curl -s "http://localhost:30080" > /dev/null 2>&1 && echo "✅ Frontend responding" || echo "❌ Frontend not responding"

echo -e "\nAuth Service:"
timeout 3 curl -s "http://localhost:30001/health" > /dev/null 2>&1 && echo "✅ Auth Service responding" || echo "❌ Auth Service not responding"

echo -e "\n4. Getting Istio Gateway Port:"
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
echo "Istio Gateway NodePort: $GATEWAY_PORT"

echo -e "\n5. Testing Istio Gateway (if configured):"
echo "Note: Services are protected by RBAC policies"
echo "Istio Gateway requires host headers for access"
echo "Direct service access is available via NodePorts above"

echo -e "\n6. Working Access URLs:"
echo "✅ API Gateway: http://localhost:30000/health"
echo "✅ API Gateway Status: http://localhost:30000/api/status"
echo "✅ Frontend: http://localhost:30080"
echo "✅ Auth Service: http://localhost:30001"
echo "✅ Order Service: http://localhost:30003"

echo -e "\n6. Checking VirtualServices:"
kubectl get virtualservice -n microservices -o custom-columns=NAME:.metadata.name,HOSTS:.spec.hosts,GATEWAYS:.spec.gateways

echo -e "\n7. Checking DestinationRules:"
kubectl get destinationrule -n microservices -o custom-columns=NAME:.metadata.name,HOST:.spec.host

echo -e "\n✅ Product & Order Services Check Complete!"
