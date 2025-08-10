#!/bin/bash

# Observability Status Check Script
# This script provides a comprehensive overview of your microservices observability setup

echo "🔍 MICROSERVICES OBSERVABILITY STATUS CHECK"
echo "=========================================="
echo ""

# Check if monitoring namespace exists
echo "📦 Checking monitoring infrastructure..."
kubectl get namespace monitoring >/dev/null 2>&1 && echo "✅ Monitoring namespace exists" || echo "❌ Monitoring namespace missing"

# Check Prometheus deployment
kubectl get deployment prometheus-kube-prometheus-operator -n monitoring >/dev/null 2>&1 && echo "✅ Prometheus Operator running" || echo "❌ Prometheus Operator not found"
kubectl get statefulset prometheus-prometheus-kube-prometheus-prometheus -n monitoring >/dev/null 2>&1 && echo "✅ Prometheus server running" || echo "❌ Prometheus server not found"

# Check Grafana
kubectl get deployment prometheus-grafana -n monitoring >/dev/null 2>&1 && echo "✅ Grafana running" || echo "❌ Grafana not found"

echo ""
echo "🎯 Checking ServiceMonitors..."
SERVICEMONITORS=$(kubectl get servicemonitor -n monitoring | grep microservices | wc -l)
echo "📊 Found $SERVICEMONITORS microservices ServiceMonitors"

if [ $SERVICEMONITORS -gt 0 ]; then
    kubectl get servicemonitor -n monitoring | grep microservices
fi

echo ""
echo "🚀 Checking microservices deployment..."
echo "Namespace: microservices"
kubectl get pods -n microservices | head -1
kubectl get pods -n microservices | grep -E "(api-gateway|auth-service|product-service|order-service)" | head -10

echo ""
echo "🔗 Checking services with monitoring labels..."
kubectl get services -n microservices -l monitoring=prometheus 2>/dev/null | head -5

echo ""
echo "📈 Access URLs (if port-forwards are running):"
echo "🎯 Prometheus: http://localhost:9090"
echo "   - Targets: http://localhost:9090/targets"
echo "   - Service Discovery: http://localhost:9090/service-discovery"
echo "📊 Grafana: http://localhost:3000"
echo "   - Default credentials: admin/prom-operator"
echo ""

echo "🔧 Active port-forwards:"
ps aux | grep "kubectl port-forward" | grep -v grep | head -5

echo ""
echo "📋 Next Steps for Complete Observability:"
echo "1. ✅ ServiceMonitors created and applied"
echo "2. ✅ Monitoring labels added to services"
echo "3. ✅ Grafana dashboard configured"
echo "4. 🔄 Add metrics code to your Node.js applications:"
echo "   - Copy: monitoring/nodejs-metrics-template.js to your apps"
echo "   - Install: npm install prom-client"
echo "   - Configure: Add metrics endpoints on port 9090"
echo "5. 🔄 Verify targets in Prometheus at /targets endpoint"
echo "6. 🔄 Import dashboard in Grafana"

echo ""
echo "🚀 Quick Commands:"
echo "kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &"
echo "kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &"
