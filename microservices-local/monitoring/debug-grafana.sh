#!/bin/bash

echo "=== Grafana Metrics Dashboard Troubleshooting ==="
echo

echo "1. Testing Prometheus access..."
kubectl exec -n monitoring deployment/prometheus -- wget -qO- "http://localhost:9090/api/v1/query?query=up" | head -200
echo

echo "2. Testing specific metrics query..."
kubectl exec -n monitoring deployment/prometheus -- wget -qO- "http://localhost:9090/api/v1/query?query=http_requests_total" | head -200
echo

echo "3. Testing Prometheus targets..."
kubectl exec -n monitoring deployment/prometheus -- wget -qO- "http://localhost:9090/api/v1/targets" | head -200
echo

echo "4. Generate some test traffic..."
for i in {1..5}; do
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1
done
echo "Generated 5 requests to each endpoint"

echo
echo "5. Current metrics from app:"
kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics
echo

echo "=== Manual Grafana Setup Instructions ==="
echo "Since automated setup might have issues, here's how to manually configure:"
echo
echo "1. Go to Grafana: http://localhost:30300"
echo "2. Login: admin / admin123"
echo "3. Go to Configuration (gear icon) -> Data Sources"
echo "4. Add data source -> Prometheus"
echo "5. URL: http://prometheus.monitoring.svc.cluster.local:9090"
echo "6. Click 'Save & Test'"
echo
echo "7. Create Dashboard:"
echo "   - Go to + -> Dashboard"
echo "   - Add Panel"
echo "   - Query: http_requests_total"
echo "   - Apply"
echo
echo "Available metrics to query:"
echo "- http_requests_total"
echo "- product_views_total" 
echo "- orders_total"
echo "- service_up"
