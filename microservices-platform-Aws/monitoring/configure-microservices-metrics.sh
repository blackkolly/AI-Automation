#!/bin/bash

# Script to patch microservices for metrics collection
# This adds the necessary configurations for Prometheus monitoring

echo "🔧 Configuring microservices for observability..."

# Create a metrics configuration patch for Node.js services
cat << 'EOF' > /tmp/metrics-patch.yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        env:
        - name: ENABLE_METRICS
          value: "true"
        - name: METRICS_PORT
          value: "9090"
        ports:
        - containerPort: 9090
          name: metrics
          protocol: TCP
EOF

# Apply metrics configuration to each microservice
echo "📊 Enabling metrics for api-gateway..."
kubectl patch deployment api-gateway -n microservices --patch-file /tmp/metrics-patch.yaml

echo "📊 Enabling metrics for auth-service..."
kubectl patch deployment auth-service -n microservices --patch-file /tmp/metrics-patch.yaml

echo "📊 Enabling metrics for product-service..."
kubectl patch deployment product-service -n microservices --patch-file /tmp/metrics-patch.yaml

echo "📊 Enabling metrics for order-service..."
kubectl patch deployment order-service -n microservices --patch-file /tmp/metrics-patch.yaml

# Create a service to expose metrics endpoints
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: microservices-metrics
  namespace: microservices
  labels:
    app: microservices
    monitoring: prometheus
spec:
  selector:
    monitoring: enabled
  ports:
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
  type: ClusterIP
EOF

# Update service labels for ServiceMonitor discovery
echo "🏷️  Adding monitoring labels to services..."
kubectl label service api-gateway -n microservices monitoring=prometheus --overwrite
kubectl label service auth-service -n microservices monitoring=prometheus --overwrite
kubectl label service product-service -n microservices monitoring=prometheus --overwrite
kubectl label service order-service -n microservices monitoring=prometheus --overwrite

# Add prometheus annotations to pods
echo "📝 Adding Prometheus annotations..."
kubectl patch deployment api-gateway -n microservices -p '{"spec":{"template":{"metadata":{"labels":{"monitoring":"enabled"}}}}}'
kubectl patch deployment auth-service -n microservices -p '{"spec":{"template":{"metadata":{"labels":{"monitoring":"enabled"}}}}}'
kubectl patch deployment product-service -n microservices -p '{"spec":{"template":{"metadata":{"labels":{"monitoring":"enabled"}}}}}'
kubectl patch deployment order-service -n microservices -p '{"spec":{"template":{"metadata":{"labels":{"monitoring":"enabled"}}}}}'

echo "✅ Microservices observability configuration complete!"
echo ""
echo "📋 Next steps:"
echo "1. Your applications need to expose /metrics endpoints on port 9090"
echo "2. Install prometheus client libraries in your Node.js apps:"
echo "   npm install prom-client"
echo "3. Add metrics collection code to your applications"
echo "4. Wait for pods to restart and check Prometheus targets"
echo ""
echo "🔍 Check if services are being discovered:"
echo "kubectl get servicemonitor -n microservices"
echo ""
echo "📊 Open Prometheus to see targets:"
echo "kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"

# Clean up
rm -f /tmp/metrics-patch.yaml
