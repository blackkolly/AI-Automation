# 🚀 Starting from the Beginning - Microservices Platform

## Prerequisites Check

Before we begin, make sure you have:

1. **Docker Desktop** installed and running
2. **Kubernetes enabled** in Docker Desktop
3. **kubectl** configured to use docker-desktop context

## Step 1: Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"
5. Wait for Kubernetes to start (green indicator)

## Step 2: Verify Setup

```bash
# Switch to Docker Desktop context
kubectl config use-context docker-desktop

# Check cluster is running
kubectl cluster-info

# Should show:
# Kubernetes control plane is running at https://127.0.0.1:6443
# CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

## Step 3: Create Namespaces

```bash
kubectl create namespace microservices
kubectl create namespace monitoring
kubectl create namespace observability
```

## Step 4: Deploy the Platform

### Deploy All Services at Once

```bash
# Deploy all microservices
kubectl apply -f k8s/local/

# Check deployment status
kubectl get pods -n microservices
kubectl get services -n microservices
```

### Deploy Monitoring (Optional)

```bash
# Deploy Prometheus and Grafana
kubectl apply -f k8s/monitoring/

# Check monitoring services
kubectl get pods -n monitoring
```

## 🎯 Access Your Platform

### 🌐 Option 1: Direct NodePort Access (If Working)

- **Frontend Dashboard**: http://localhost:30080
- **API Gateway**: http://localhost:30000
- **Auth Service**: http://localhost:30001
- **Product Service**: http://localhost:30002
- **Order Service**: http://localhost:30003

### 🔧 Option 2: Port Forwarding (Recommended for Docker Desktop)

If NodePort access isn't working (common with Docker Desktop on Windows), use port forwarding:

```bash
# Run the port forward setup script
./scripts/start-port-forwards.sh

# Or manually set up port forwards:
kubectl port-forward -n microservices svc/frontend 8080:80 &
kubectl port-forward -n microservices svc/api-gateway 30000:3000 &
kubectl port-forward -n microservices svc/product-service 30002:3002 &
kubectl port-forward -n microservices svc/order-service 30003:3003 &
```

**Access URLs with Port Forwarding:**

- **Frontend Dashboard**: http://localhost:8080
- **API Gateway**: http://localhost:30000
- **Product Service**: http://localhost:30002 (try `/products`)
- **Order Service**: http://localhost:30003 (try `/orders`)

### 📊 Monitoring & Observability

**Direct Access (if NodePorts work):**

- **Grafana**: http://localhost:30300 (admin/prom-operator)
- **Prometheus**: http://localhost:30090
- **Jaeger**: http://localhost:30686

**Port Forward Access:**

```bash
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80 &
kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090 &
kubectl port-forward -n observability svc/jaeger-query 16686:80 &
```

- **Grafana**: http://localhost:3000 (admin/prom-operator)
- **Prometheus**: http://localhost:9090
- **Jaeger**: http://localhost:16686

## Current Platform Status

✅ **FULLY DEPLOYED**: Complete microservices platform running locally

### 🎉 Platform Components Status

| Component                 | Status     | Port  | Description                           |
| ------------------------- | ---------- | ----- | ------------------------------------- |
| 🌐 **Frontend Dashboard** | ✅ Running | 30080 | Web interface for platform management |
| 🚪 **API Gateway**        | ✅ Running | 30000 | Main entry point and routing          |
| 🔐 **Auth Service**       | ✅ Running | 30001 | Authentication and authorization      |
| 📦 **Product Service**    | ✅ Running | 30002 | Product catalog management            |
| 🛒 **Order Service**      | ✅ Running | 30003 | Order processing and management       |
| 📊 **Grafana**            | ✅ Running | 30300 | Metrics visualization dashboards      |
| 🔍 **Prometheus**         | ✅ Running | 30090 | Metrics collection and storage        |
| 🔍 **Jaeger**             | ✅ Running | 30686 | Distributed tracing and monitoring    |

### 🎯 Next Steps

1. **Explore the Dashboard**: Visit http://localhost:30080 to see your platform in action
2. **Monitor Services**: Check real-time health status and test individual services
3. **View Metrics**: Access Grafana dashboards for detailed performance insights
4. **Trace Requests**: Use Jaeger to understand request flows between services
5. **Experiment**: Try the product and order management features

### 🛠️ Development Tips

- All services have health endpoints at `/health`
- Services expose metrics on port 9090 for Prometheus scraping
- Logs can be viewed with: `kubectl logs -n microservices <pod-name>`
- Scale services with: `kubectl scale deployment <service-name> --replicas=3 -n microservices`

### 🔧 Troubleshooting

If services aren't accessible via NodePort (common with Docker Desktop):

```bash
# Use port forwarding instead
kubectl port-forward -n microservices svc/frontend 8080:80 &
kubectl port-forward -n microservices svc/api-gateway 30000:3000 &
kubectl port-forward -n microservices svc/product-service 30002:3002 &
kubectl port-forward -n microservices svc/order-service 30003:3003 &

# Test the services
curl http://localhost:30000/health     # API Gateway
curl http://localhost:30002/products   # Products
curl http://localhost:30003/orders     # Orders
```

If pods aren't starting:

```bash
# Check pod status
kubectl get pods -n microservices

# Check service endpoints
kubectl get endpoints -n microservices

# View logs
kubectl logs -n microservices -l app=api-gateway
```

### 🧪 Testing Your Platform

1. **Service Health Checks:**

```bash
# Test all health endpoints
kubectl exec -n microservices deployment/api-gateway -- wget -q -O- http://localhost:3000/health
kubectl exec -n microservices deployment/product-service -- wget -q -O- http://localhost:3002/health
kubectl exec -n microservices deployment/order-service -- wget -q -O- http://localhost:3003/health
```

2. **API Testing:**

```bash
# Get products (via port forward)
curl http://localhost:30002/products

# Get orders (via port forward)
curl http://localhost:30003/orders
```

3. **Frontend Testing:**
   - Visit http://localhost:8080 (via port forward) or http://localhost:30080 (direct NodePort)
   - Click "Test" buttons for each service
   - Try "Load Products" and "Load Orders" features
   - Check monitoring links

---

**🎊 Congratulations!**

Your complete microservices platform is now running locally with:

- ✅ 4 Node.js microservices with health checks
- ✅ Interactive web dashboard
- ✅ Full monitoring stack (Prometheus, Grafana, Jaeger)
- ✅ Production-ready networking and service discovery
- ✅ Working API endpoints with sample data

**Next Steps:** Explore the frontend dashboard, experiment with the APIs, and check out the monitoring tools!

✅ Docker Desktop Kubernetes is running!
✅ Cluster accessible at https://127.0.0.1:51589
✅ Ready to deploy microservices platform

## Next Steps

Now let's deploy step by step:

1. ✅ Kubernetes cluster running
2. 🎯 **NEXT:** Create namespaces
3. 🎯 **THEN:** Deploy core services
4. 🎯 **THEN:** Add monitoring stack
5. 🎯 **FINALLY:** Add security and observability
