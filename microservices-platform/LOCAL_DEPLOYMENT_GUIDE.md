# Local Deployment Guide - Docker Desktop Kubernetes

## Overview

This guide will help you deploy the entire microservices platform locally on Docker Desktop Kubernetes - completely free and without any AWS charges! You'll get the full experience including:

- ✅ All 4 microservices (API Gateway, Auth, Product, Order)
- ✅ Complete monitoring stack (Prometheus, Grafana, AlertManager)
- ✅ Distributed tracing with Jaeger
- ✅ Local storage and databases
- ✅ All dashboards and observability features

## Prerequisites

### 1. Docker Desktop Setup

```bash
# Download and install Docker Desktop from:
# https://www.docker.com/products/docker-desktop

# Enable Kubernetes in Docker Desktop:
# Docker Desktop → Settings → Kubernetes → Enable Kubernetes
# Apply & Restart
```

### 2. Resource Requirements

```bash
# Recommended Docker Desktop settings:
Memory: 8GB (minimum 6GB)
CPUs: 4 cores (minimum 2)
Disk: 20GB available space
```

### 3. Required Tools

```bash
# Install kubectl (if not already installed)
# Windows (using chocolatey):
choco install kubernetes-cli

# Or download directly:
# https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

# Install Helm
choco install kubernetes-helm

# Verify installations
kubectl version --client
helm version
```

## Quick Start

### 1. Verify Kubernetes Context

```bash
# Make sure you're using docker-desktop context
kubectl config current-context
# Should show: docker-desktop

# If not, switch to docker-desktop
kubectl config use-context docker-desktop

# Verify cluster is running
kubectl get nodes
```

### 2. Create Namespaces

```bash
# Create required namespaces
kubectl create namespace microservices
kubectl create namespace monitoring
kubectl create namespace observability
kubectl create namespace argocd
```

## Deployment Steps

### Step 1: Deploy Monitoring Stack First

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack with local configuration
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30903 \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi
```

### Step 2: Deploy Jaeger for Tracing

```bash
# Add Jaeger Helm repository
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# Install Jaeger with local storage
helm install jaeger jaegertracing/jaeger \
  --namespace observability \
  --set query.service.type=NodePort \
  --set query.service.nodePort=30686 \
  --set collector.service.type=ClusterIP \
  --set agent.daemonset.enabled=true \
  --set storage.type=memory
```

### Step 3: Build and Deploy Microservices

#### Option A: Using Pre-built Images (Recommended)

```bash
# Deploy all microservices using local manifests
kubectl apply -f k8s/local/ -n microservices
```

#### Option B: Build Images Locally

```bash
# Build all microservice images
docker build -t api-gateway:local ./services/api-gateway
docker build -t auth-service:local ./services/auth-service
docker build -t product-service:local ./services/product-service
docker build -t order-service:local ./services/order-service

# Deploy with local images
kubectl apply -f k8s/local-dev/ -n microservices
```

### Step 4: Deploy Service Monitors

```bash
# Deploy ServiceMonitors for Prometheus discovery
kubectl apply -f monitoring/local-servicemonitors.yaml -n monitoring
```

## Access URLs

Once deployed, access your services at:

| Service          | URL                    | Credentials           |
| ---------------- | ---------------------- | --------------------- |
| **Grafana**      | http://localhost:30300 | admin / prom-operator |
| **Prometheus**   | http://localhost:30090 | No auth required      |
| **AlertManager** | http://localhost:30903 | No auth required      |
| **Jaeger UI**    | http://localhost:30686 | No auth required      |
| **API Gateway**  | http://localhost:30000 | No auth required      |

### Microservice Endpoints

```bash
# API Gateway (main entry point)
curl http://localhost:30000/health

# Direct service access
curl http://localhost:30001/auth/health    # Auth Service
curl http://localhost:30002/products       # Product Service
curl http://localhost:30003/orders         # Order Service
```

## Local Configuration Files

Let me create the necessary local deployment configurations:
