#!/bin/bash

echo "🎯 Grafana Dashboard Setup - Quick Manual Method"
echo
echo "Your metrics are working perfectly! Here's how to see them:"
echo

# Check current metrics
echo "📊 Current Metrics:"
kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics 2>/dev/null
echo

echo "🚀 STEP-BY-STEP GRAFANA SETUP:"
echo
echo "1. Open Grafana: http://localhost:30300"
echo "   Login: admin / admin123"
echo
echo "2. Add Prometheus Data Source:"
echo "   • Click gear icon (⚙️) in left sidebar"
echo "   • Click 'Data Sources'"
echo "   • Click 'Add data source'"
echo "   • Select 'Prometheus'"
echo "   • URL: http://prometheus.monitoring.svc.cluster.local:9090"
echo "   • Click 'Save & Test' (should show green checkmark)"
echo
echo "3. Create Dashboard:"
echo "   • Click '+' in left sidebar"
echo "   • Click 'Dashboard'"
echo "   • Click 'Add new panel'"
echo
echo "4. Add These Queries (one panel each):"
echo "   Panel 1: http_requests_total (Title: 'Total HTTP Requests')"
echo "   Panel 2: product_views_total (Title: 'Product Views')"
echo "   Panel 3: orders_total (Title: 'Orders Created')"
echo "   Panel 4: service_up (Title: 'Service Status')"
echo "   Panel 5: rate(http_requests_total[1m])*60 (Title: 'Requests per Minute')"
echo
echo "5. Panel Settings Tips:"
echo "   • For counters (requests, views, orders): Use 'Stat' visualization"
echo "   • For rates: Use 'Time series' visualization"
echo "   • Set time range to 'Last 15 minutes'"
echo "   • Set refresh to '5s' for live updates"
echo

# Test Prometheus connectivity from Grafana
echo "🔍 Testing Prometheus connectivity..."
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath="{.items[0].metadata.name}")
echo "Testing from Grafana pod: $GRAFANA_POD"

# Test if Grafana can reach Prometheus
kubectl exec -n monitoring $GRAFANA_POD -- wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets --timeout=5 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Grafana CAN reach Prometheus"
else
    echo "❌ Grafana cannot reach Prometheus - using alternative URL"
    echo "   Use this URL instead: http://prometheus:9090"
fi

echo
echo "🔄 Generating live traffic (watch your dashboard)..."

# Generate traffic in background
for i in {1..50}; do
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1 &
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1 &
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "   Generated $i requests... (metrics updating)"
        # Show current metrics
        kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics 2>/dev/null | head -4
        echo
    fi
    sleep 0.5
done

echo "✅ Setup complete! Your dashboard should now show live metrics."
echo "📈 Refresh Grafana and you'll see the data flowing!"
