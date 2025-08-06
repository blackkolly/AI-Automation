#!/bin/bash

echo "🔄 Generating Istio Service Mesh Traffic"
echo "========================================"

echo "1. Checking Istio sidecar injection..."
kubectl get pods -n microservices -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

echo -e "\n2. Testing inter-service communication..."

# Test from API Gateway to other services (this should generate Istio traffic)
echo "Testing API Gateway → Product Service:"
kubectl exec -n microservices deployment/api-gateway -c api-gateway -- wget -qO- --timeout=5 "http://product-service.microservices.svc.cluster.local:80/health" 2>/dev/null || echo "❌ Failed (RBAC blocked)"

echo -e "\nTesting API Gateway → Order Service:"
kubectl exec -n microservices deployment/api-gateway -c api-gateway -- wget -qO- --timeout=5 "http://order-service.microservices.svc.cluster.local:3003/health" 2>/dev/null || echo "❌ Failed (RBAC blocked)"

echo -e "\n3. Generating external traffic through Istio Gateway..."
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

echo "Gateway Port: $GATEWAY_PORT"
echo "Sending requests through Istio Gateway..."

for i in {1..5}; do
    echo "Request $i:"
    curl -s -H "Host: microservices.local" --max-time 3 "http://localhost:$GATEWAY_PORT/product/health" || echo "  ❌ Failed"
    sleep 1
done

echo -e "\n4. Generating traffic to working services..."
echo "API Gateway traffic:"
for i in {1..3}; do
    curl -s "http://localhost:30000/health" > /dev/null && echo "  ✅ Request $i successful" || echo "  ❌ Request $i failed"
done

echo -e "\nOrder Service traffic:"
for i in {1..3}; do
    curl -s "http://localhost:30003/orders" > /dev/null && echo "  ✅ Request $i successful" || echo "  ❌ Request $i failed"
done

echo -e "\n5. Checking Istio proxy stats..."
kubectl exec -n microservices deployment/api-gateway -c istio-proxy -- pilot-agent request GET stats/prometheus | grep istio | head -5 2>/dev/null || echo "❌ No Istio proxy stats available"

echo -e "\n✅ Traffic generation complete!"
echo "Check Kiali dashboard to see the traffic flow."
