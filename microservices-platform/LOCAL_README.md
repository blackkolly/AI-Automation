# 🏠 Local Deployment - Microservices Platform

## 🎯 Overview

Deploy the complete microservices platform locally on Docker Desktop Kubernetes - **100% FREE** and no AWS charges! This gives you the full production experience including:

- ✅ **4 Microservices**: API Gateway, Auth, Product, Order services
- ✅ **Complete Monitoring**: Prometheus, Grafana, AlertManager
- ✅ **Distributed Tracing**: Jaeger with full trace collection
- ✅ **Service Discovery**: Automatic service monitoring
- ✅ **Professional Dashboards**: Pre-configured Grafana dashboards
- ✅ **Metrics Collection**: Custom application metrics
- ✅ **Local Storage**: Persistent volumes for data retention

## 🚀 Quick Start (5 Minutes)

### Prerequisites

1. **Docker Desktop** with Kubernetes enabled

   - Memory: 8GB recommended (6GB minimum)
   - CPUs: 4 cores recommended (2 minimum)
   - Storage: 20GB available

2. **Tools** (install if not available):
   ```bash
   # Windows (using chocolatey)
   choco install kubernetes-cli
   choco install kubernetes-helm
   ```

### Deploy Everything

```bash
# 1. Navigate to the project directory
cd "c:\Users\hp\Desktop\AWS\Kubernetes_Project\microservices-platform"

# 2. Make scripts executable
chmod +x *.sh

# 3. Deploy the entire platform
./deploy-local.sh
```

### Access Your Platform

After deployment (takes ~5 minutes), access your services:

| Service             | URL                    | Credentials               |
| ------------------- | ---------------------- | ------------------------- |
| **🎨 Grafana**      | http://localhost:30300 | `admin` / `prom-operator` |
| **📊 Prometheus**   | http://localhost:30090 | No auth                   |
| **🚨 AlertManager** | http://localhost:30903 | No auth                   |
| **🔍 Jaeger UI**    | http://localhost:30686 | No auth                   |
| **🌐 API Gateway**  | http://localhost:30000 | No auth                   |

## 🧪 Testing Your Deployment

```bash
# Test all services and generate sample data
./test-local.sh
```

This script will:

- ✅ Test all service endpoints
- ✅ Verify metrics collection
- ✅ Check Prometheus service discovery
- ✅ Generate sample traffic for dashboards
- ✅ Display pod status

## 📊 Exploring Your Platform

### 1. **Grafana Dashboards**

```bash
# Access: http://localhost:30300
# Login: admin / prom-operator

# Pre-installed dashboards:
- Kubernetes Cluster Monitoring
- Node Exporter Full
- Kubernetes / Compute Resources / Workload
- Prometheus 2.0 Overview
```

### 2. **Prometheus Metrics**

```bash
# Access: http://localhost:30090

# Check service discovery: Status → Targets
# Query examples:
- rate(http_requests_total[5m])
- container_memory_usage_bytes
- up{job=~".*-service"}
```

### 3. **Jaeger Tracing**

```bash
# Access: http://localhost:30686

# Available services:
- api-gateway
- auth-service
- product-service
- order-service
```

### 4. **Microservice APIs**

```bash
# API Gateway (main entry point)
curl http://localhost:30000/api/status

# Individual services
curl http://localhost:30001/health    # Auth
curl http://localhost:30002/products  # Products
curl http://localhost:30003/orders    # Orders

# Get sample product data
curl http://localhost:30002/products | jq

# Create a test order
curl -X POST http://localhost:30003/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 1, "userId": "test", "quantity": 2}'
```

## 🏗️ Architecture Overview

```
Local Docker Desktop Kubernetes
├── monitoring namespace
│   ├── Prometheus Stack (Helm)
│   ├── Grafana (NodePort 30300)
│   ├── Prometheus (NodePort 30090)
│   └── AlertManager (NodePort 30903)
├── observability namespace
│   └── Jaeger (NodePort 30686)
└── microservices namespace
    ├── api-gateway (NodePort 30000)
    ├── auth-service (NodePort 30001)
    ├── product-service (NodePort 30002)
    └── order-service (NodePort 30003)
```

## 🛠️ Development Workflow

### Making Changes

```bash
# Edit service code in k8s/local/
# Then redeploy specific service:
kubectl apply -f k8s/local/api-gateway.yaml -n microservices

# Or redeploy everything:
kubectl apply -f k8s/local/ -n microservices
```

### Viewing Logs

```bash
# Service logs
kubectl logs -f deployment/api-gateway -n microservices
kubectl logs -f deployment/auth-service -n microservices

# Monitoring logs
kubectl logs -f deployment/prometheus-stack-grafana -n monitoring
```

### Scaling Services

```bash
# Scale up microservices
kubectl scale deployment api-gateway --replicas=2 -n microservices
kubectl scale deployment product-service --replicas=3 -n microservices
```

## 🔧 Customization

### Adding Custom Metrics

Each service includes a metrics template. Customize in the deployment YAML:

```javascript
// Example: Add custom business metrics
const ordersProcessed = new client.Counter({
  name: "orders_processed_total",
  help: "Total orders processed",
  labelNames: ["status"],
});

// Use in your code
ordersProcessed.inc({ status: "completed" });
```

### Adding Custom Dashboards

1. Create dashboard in Grafana UI
2. Export JSON
3. Save as ConfigMap:

```bash
kubectl create configmap my-dashboard \
  --from-file=dashboard.json \
  -n monitoring
```

### Custom Alerting Rules

Edit `monitoring/alerts/rules.yml` and apply:

```bash
kubectl apply -f monitoring/alerts/ -n monitoring
```

## 🧹 Cleanup

### Remove Everything

```bash
# Clean up all resources
./cleanup-local.sh
```

### Selective Cleanup

```bash
# Remove only microservices
kubectl delete -f k8s/local/ -n microservices

# Remove only monitoring
helm uninstall prometheus-stack -n monitoring
helm uninstall jaeger -n observability
```

## 🐛 Troubleshooting

### Common Issues

1. **Services Not Starting**

   ```bash
   # Check pod status
   kubectl get pods -n microservices
   kubectl describe pod <pod-name> -n microservices
   ```

2. **Prometheus Not Scraping**

   ```bash
   # Check ServiceMonitor
   kubectl get servicemonitor -n monitoring
   kubectl describe servicemonitor microservices-local-monitor -n monitoring
   ```

3. **Grafana Login Issues**

   ```bash
   # Reset Grafana password
   kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
   ```

4. **Not Enough Resources**
   ```bash
   # Reduce resource requirements
   kubectl edit deployment prometheus-stack-kube-prom-prometheus -n monitoring
   # Set smaller resource requests/limits
   ```

### Performance Optimization

1. **Reduce Scrape Intervals**:
   Edit ServiceMonitors to increase interval from 30s to 60s

2. **Limit Retention**:
   Prometheus is configured for 7 days retention locally

3. **Memory Limits**:
   Adjust Docker Desktop memory allocation if needed

## 📚 Learning Resources

### Prometheus Queries to Try

```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total{namespace="microservices"}[5m])

# Memory usage by service
container_memory_usage_bytes{namespace="microservices"}

# HTTP request rate
rate(http_requests_total{namespace="microservices"}[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

### Grafana Dashboard Ideas

- Request latency percentiles
- Error rate trends
- Service dependency mapping
- Resource utilization by service
- Custom business metrics

## 🎓 Next Steps

1. **Explore Monitoring**: Create custom dashboards in Grafana
2. **Add Features**: Extend microservices with new endpoints
3. **Practice Observability**: Use Jaeger to trace requests
4. **Learn PromQL**: Write custom Prometheus queries
5. **Simulate Issues**: Test alerting by causing errors

## 🆘 Support

If you encounter issues:

1. **Check Prerequisites**: Ensure Docker Desktop Kubernetes is running
2. **Resource Allocation**: Verify Docker Desktop has enough memory
3. **Run Tests**: Use `./test-local.sh` to verify deployment
4. **Check Logs**: Use kubectl logs to debug issues
5. **Clean & Retry**: Run `./cleanup-local.sh` then `./deploy-local.sh`

---

**🎉 Enjoy your local microservices platform!**

You now have a complete production-like environment running locally for free. Perfect for learning, development, and experimentation without any AWS costs.
