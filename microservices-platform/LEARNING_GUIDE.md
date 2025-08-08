# 🎓 Kubernetes Learning Deployment Guide

This guide walks you through deploying a complete microservices platform step by step for learning purposes.

## 📚 Learning Objectives

By following this guide, you'll learn:

- How to deploy frontend applications in Kubernetes
- Microservices architecture and deployment patterns
- Observability stack (monitoring, logging, tracing)
- Service mesh concepts with Istio
- Real-world production-ready configurations

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │    │   Microservices │    │  Observability  │
│                 │────│                 │────│                 │
│ • React App     │    │ • API Gateway   │    │ • Prometheus    │
│ • Nginx         │    │ • Auth Service  │    │ • Grafana       │
│                 │    │ • Product Svc   │    │ • Jaeger        │
│                 │    │ • Order Service │    │ • AlertManager  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Istio Mesh    │
                    │                 │
                    │ • Traffic Mgmt  │
                    │ • Security      │
                    │ • Observability │
                    └─────────────────┘
```

## 🚀 Deployment Sequence

### Phase 1: Infrastructure Setup

```bash
# 1. Create namespaces
kubectl create namespace microservices
kubectl create namespace monitoring
kubectl create namespace observability
```

### Phase 2: Frontend Deployment

**Location:** `./frontend/`

**What you'll learn:**

- Containerized frontend deployment
- ConfigMaps for configuration
- Services and ingress

**Deploy:**

```bash
kubectl apply -f frontend/
```

### Phase 3: Core Services

**Location:** `./services/`

**What you'll learn:**

- Microservices communication patterns
- Environment variables and secrets
- Health checks and readiness probes
- Service discovery

**Services to deploy in order:**

1. **API Gateway** (`./services/api-gateway/`)
2. **Auth Service** (`./services/auth-service/`)
3. **Product Service** (`./services/product-service/`)
4. **Order Service** (`./services/order-service/`)

**Deploy:**

```bash
kubectl apply -f services/api-gateway/k8s/
kubectl apply -f services/auth-service/k8s/
kubectl apply -f services/product-service/k8s/
kubectl apply -f services/order-service/k8s/
```

### Phase 4: Observability Stack

**Location:** `./monitoring/`, `./logging/`, `./tracing/`

**What you'll learn:**

- Prometheus for metrics collection
- Grafana for visualization
- Jaeger for distributed tracing
- Log aggregation and analysis
- AlertManager for notifications

**Deploy in this order:**

```bash
# 1. Monitoring (Prometheus + Grafana)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml

# 2. Distributed Tracing (Jaeger)
kubectl apply -f tracing/manifests/

# 3. Logging (Optional - ELK stack)
kubectl apply -f logging/manifests/
```

### Phase 5: Service Mesh (Istio)

**Location:** `./Istio/`

**What you'll learn:**

- Service mesh architecture
- Traffic management and load balancing
- Security policies and mTLS
- Advanced observability
- Circuit breakers and resilience

**Deploy:**

```bash
# 1. Install Istio (manual learning approach)
# Download Istio CLI first: https://istio.io/latest/docs/setup/getting-started/

# 2. Apply configurations for learning
kubectl apply -f Istio/configs/gateway.yaml
kubectl apply -f Istio/configs/virtual-services.yaml
kubectl apply -f Istio/configs/destination-rules.yaml
kubectl apply -f Istio/configs/security-policies.yaml
kubectl apply -f Istio/configs/observability-config.yaml

# 3. Install Kiali dashboard
kubectl apply -f Istio/addons/kiali.yaml
```

## 🔍 Learning Checkpoints

After each phase, verify your deployment:

### Phase 2 Verification:

```bash
kubectl get pods -n microservices | grep frontend
kubectl get svc -n microservices | grep frontend
```

### Phase 3 Verification:

```bash
kubectl get pods -n microservices
curl http://localhost:30000/health  # API Gateway
curl http://localhost:30001/health  # Auth Service
curl http://localhost:30002/health  # Product Service
curl http://localhost:30003/health  # Order Service
```

### Phase 4 Verification:

```bash
kubectl get pods -n monitoring
kubectl get pods -n observability
# Access Grafana: http://localhost:30300
# Access Prometheus: http://localhost:30090
# Access Jaeger: http://localhost:30686
```

### Phase 5 Verification:

```bash
kubectl get pods -n istio-system
kubectl get gateway -n microservices
kubectl get virtualservice -n microservices
```

## 📖 Key Concepts to Learn

### 1. Frontend (Phase 2)

- **Containerization**: How frontend apps run in containers
- **Static File Serving**: Nginx configuration for SPAs
- **Environment Variables**: Runtime configuration injection

### 2. Microservices (Phase 3)

- **Service Communication**: How services talk to each other
- **API Gateway Pattern**: Central entry point for requests
- **Database per Service**: Each service has its own data
- **Health Checks**: Monitoring service availability

### 3. Observability (Phase 4)

- **Metrics Collection**: What to measure and why
- **Log Aggregation**: Centralized logging strategies
- **Distributed Tracing**: Following requests across services
- **Alerting**: When and how to notify on issues

### 4. Service Mesh (Phase 5)

- **Traffic Management**: Load balancing and routing
- **Security**: mTLS and authentication
- **Circuit Breaking**: Handling service failures
- **Observability**: Enhanced monitoring capabilities

## 🛠️ Hands-on Exercises

1. **Modify a service** and observe how changes propagate
2. **Scale services** up and down and watch load distribution
3. **Inject failures** and see how the system responds
4. **Create custom dashboards** in Grafana
5. **Set up alerts** for critical metrics
6. **Configure canary deployments** with Istio

## 📚 Additional Resources

- Kubernetes Documentation: https://kubernetes.io/docs/
- Istio Documentation: https://istio.io/latest/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Jaeger Documentation: https://www.jaegertracing.io/docs/

## 🎯 Next Steps

After completing this guide:

1. Experiment with different Istio traffic policies
2. Set up monitoring alerts for your services
3. Implement security policies
4. Try blue-green deployments
5. Add more services to the mesh

---

**Remember**: This is for learning! Take time to understand each component before moving to the next phase. Experiment, break things, and fix them - that's how you learn best! 🚀
