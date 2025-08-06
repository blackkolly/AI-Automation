#!/bin/bash

echo "🧪 Testing Product and Order Services"
echo "====================================="

# Get the correct Istio Gateway port
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
echo "Istio Gateway Port: $GATEWAY_PORT"

# Test Product Service
echo -e "\n🔍 Testing Product Service:"
echo "URL: http://localhost:$GATEWAY_PORT/product/health"
echo "Host: microservices.local"

response=$(curl -s -w "HTTPSTATUS:%{http_code}" -H "Host: microservices.local" --connect-timeout 10 "http://localhost:$GATEWAY_PORT/product/health" 2>/dev/null)
http_code=$(echo $response | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
body=$(echo $response | sed -E 's/HTTPSTATUS:[0-9]{3}$//')

if [ "$http_code" = "200" ]; then
    echo "✅ Product Service: HEALTHY"
    echo "Response: $body"
else
    echo "❌ Product Service: HTTP $http_code"
    echo "Response: $body"
fi

# Test Order Service  
echo -e "\n🔍 Testing Order Service:"
echo "URL: http://localhost:$GATEWAY_PORT/order/health"
echo "Host: microservices.local"

response=$(curl -s -w "HTTPSTATUS:%{http_code}" -H "Host: microservices.local" --connect-timeout 10 "http://localhost:$GATEWAY_PORT/order/health" 2>/dev/null)
http_code=$(echo $response | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
body=$(echo $response | sed -E 's/HTTPSTATUS:[0-9]{3}$//')

if [ "$http_code" = "200" ]; then
    echo "✅ Order Service: HEALTHY"
    echo "Response: $body"
else
    echo "❌ Order Service: HTTP $http_code"
    echo "Response: $body"
fi

echo -e "\n📊 Summary:"
echo "Gateway Port: $GATEWAY_PORT"
echo "Both services should be accessible via Istio Gateway"
