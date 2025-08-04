#!/bin/bash

# Frontend Dashboard (Port 8080)
#     ↓
# ┌─────────────────────────────────────────┐
# │           MICROSERVICES                 │
# │  API Gateway → Auth/Product/Order/DB    │
# └─────────────────────────────────────────┘
#     ↓
# ┌─────────────────────────────────────────┐
# │        MONITORING STACK                 │
# │  Prometheus → Grafana → Jaeger          │
# │  (Metrics)   (Dashboards) (Tracing)     │
# └─────────────────────────────────────────┘

echo "=== Microservices Metrics Dashboard Setup ==="
echo

echo "1. Your monitoring services are running:"
kubectl get pods -n monitoring
echo

echo "2. Your metrics application is running:"
kubectl get pods -n microservices | grep metrics
echo

echo "3. Current application metrics:"
kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics
echo

echo "4. Generating test traffic to create metrics..."
for i in {1..10}; do
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1
    echo "Generated request $i"
done
echo

echo "5. Updated metrics after traffic:"
kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics
echo

echo "=== Access Information ==="
echo "Grafana Dashboard: http://localhost:30300"
echo "Username: admin"
echo "Password: admin123"
echo
echo "Prometheus: http://localhost:30090"
echo
echo "To see metrics in Grafana:"
echo "1. Go to http://localhost:30300"
echo "2. Login with admin/admin123"
echo "3. Go to Dashboards -> Browse"
echo "4. Look for 'Microservices Dashboard' or create a new dashboard"
echo "5. Add panels with these metrics:"
echo "   - http_requests_total"
echo "   - product_views_total"
echo "   - orders_total"
echo "   - service_up"
echo

echo "=== Sample Grafana Queries ==="
echo "Request Rate: rate(http_requests_total[5m])"
echo "Product Views: rate(product_views_total[5m])"
echo "Orders: rate(orders_total[5m])"
echo "Service Status: service_up"
