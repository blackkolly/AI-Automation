# 🚀 Production-Grade Microservices Platform

A complete, production-ready microservices platform with modern web frontend, comprehensive monitoring, and full CI/CD integration.

![Architecture](https://img.shields.io/badge/Architecture-Microservices-blue)
![Frontend](https://img.shields.io/badge/Frontend-HTML5%20%7C%20CSS3%20%7C%20JavaScript-orange)
![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Spring%20Boot-green)
![Infrastructure](https://img.shields.io/badge/Infrastructure-Docker%20%7C%20Kubernetes-blue)
![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus%20%7C%20Grafana%20%7C%20Jaeger-purple)

## 🎯 Overview

This platform demonstrates a complete microservices architecture with:
- **Modern Frontend**: Single-page application with authentication, shopping cart, and real-time updates
- **Microservices Backend**: 4 specialized services (Auth, Gateway, Product, Order)
- **Message Broker**: Kafka for async communication and event streaming
- **Monitoring Stack**: Prometheus, Grafana, Jaeger for observability
- **Local Development**: Complete Docker Compose setup
- **Production Ready**: Kubernetes manifests and Terraform infrastructure

## ⚡ Quick Start

### 🖥️ **Windows Users**
```cmd
# Double-click start.bat or run in Command Prompt
start.bat
```

### 🐧 **Linux/Mac Users**  
```bash
# Make script executable and run
chmod +x start.sh
./start.sh
```

### 🐳 **Manual Docker Compose**
```bash
# Start all services
docker-compose -f docker-compose.local.yml up -d

# Open frontend
open http://localhost:8080
```

## 🏗️ Architecture

### 🎨 Frontend (Single-Page Application)
- **Technology**: HTML5, CSS3, JavaScript ES6+
- **Features**: Authentication, product catalog, shopping cart, order management
- **Real-time**: WebSocket integration for live updates
- **Responsive**: Mobile-first design with modern UI components

### � Backend Services

| Service | Technology | Port | Purpose |
|---------|------------|------|---------|
| **Frontend** | Nginx + Static Files | 8080 | Web application UI |
| **API Gateway** | Node.js + Express | 3001 | Request routing, rate limiting |
| **Auth Service** | Node.js + JWT | 3000 | User authentication & authorization |
| **Product Service** | Spring Boot + JPA | 8082 | Product catalog management |
| **Order Service** | Node.js + Kafka | 3002 | Order processing & events |

### 🗄️ Data Layer
- **PostgreSQL**: Primary database for all services
- **Redis**: Caching and session storage
- **Kafka**: Event streaming and async messaging

### 📊 Observability
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Jaeger**: Distributed tracing
- **ELK Stack**: Centralized logging
├── 📁 gitops/                     # GitOps Configuration
│   ├── argocd/                   # ArgoCD Applications
│   └── applications/             # Application Definitions
├── 📁 observability/              # Monitoring & Logging
│   ├── prometheus/               # Metrics Collection
│   ├── grafana/                  # Dashboards
│   ├── loki/                     # Log Aggregation
│   └── jaeger/                   # Distributed Tracing
├── 📁 security/                   # Security Tools
│   ├── vault/                    # Secrets Management
│   ├── policies/                 # Network & Security Policies
│   └── scanning/                 # Security Scanning
├── 📁 service-mesh/               # Istio Service Mesh
└── 📁 ci-cd/                     # CI/CD Pipelines
```

## 🏗️ Technology Stack

### 🎯 **1. Microservices Architecture**
- **Auth Service**: Node.js + Express + JWT
- **API Gateway**: Node.js + Express + Rate Limiting
- **Product Service**: Spring Boot + JPA + PostgreSQL
- **Order Service**: Node.js + Kafka + Redis

### 🐳 **2. Containerization**
- **Docker**: Multi-stage builds for optimized images
- **Container Registry**: AWS ECR / Google GCR
- **Security**: Trivy image scanning

### ☸️ **3. Kubernetes Platform**
- **Managed Kubernetes**: EKS (AWS) / GKE (GCP) / AKS (Azure)
- **Package Management**: Helm 3.x
- **Configuration Management**: Kustomize
- **Networking**: Istio Service Mesh

### 🏗️ **4. Infrastructure as Code**
- **Terraform**: Infrastructure provisioning
- **Terragrunt**: Multi-environment management
- **Modules**: Reusable infrastructure components

### 🔄 **5. CI/CD Pipeline**
- **GitHub Actions**: Automated workflows
- **GitOps**: ArgoCD for deployment automation
- **Registry**: Automated image building and pushing

### 📊 **6. Observability Stack**
- **Metrics**: Prometheus + Grafana
- **Logging**: Loki + Promtail
- **Tracing**: Jaeger
- **Alerting**: Alertmanager + Slack/PagerDuty

### 🔒 **7. Security**
- **Image Scanning**: Trivy
- **SAST**: SonarQube
- **Secrets**: HashiCorp Vault
- **Network Policies**: Calico
- **Admission Control**: OPA Gatekeeper

### 🌐 **8. Service Mesh**
- **Istio**: Traffic management, security, observability
- **mTLS**: Automatic mutual TLS
- **Circuit Breakers**: Resilience patterns

### 🔄 **9. GitOps**
- **ArgoCD**: Declarative continuous delivery
- **Git Repository**: Single source of truth
- **Automated Sync**: Infrastructure and applications

### ⚡ **10. Scalability & Resilience**
- **HPA**: Horizontal Pod Autoscaling
- **VPA**: Vertical Pod Autoscaling
- **PDB**: Pod Disruption Budgets
- **Node Autoscaling**: Cluster autoscaler

## 🚀 Quick Start

### Prerequisites
```bash
# Required tools
- Docker 20.x+
- kubectl 1.25+
- helm 3.x+
- terraform 1.x+
- terragrunt 0.45+
- AWS CLI / gcloud CLI
```

### 1. Infrastructure Setup
```bash
# Navigate to infrastructure
cd infrastructure/terraform

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 2. Deploy Observability Stack
```bash
# Install monitoring stack
helm upgrade --install monitoring observability/prometheus/
helm upgrade --install grafana observability/grafana/
```

### 3. Deploy Applications via GitOps
```bash
# Apply ArgoCD applications
kubectl apply -f gitops/argocd/applications/
```

## 📈 Benefits

### 🔧 **Development Benefits**
- **Polyglot Environment**: Multiple programming languages and frameworks
- **Microservices Patterns**: Independent scaling and deployment
- **Local Development**: Docker Compose for local testing

### 🚀 **Operational Benefits**
- **Zero-Downtime Deployments**: Rolling updates and blue-green deployments
- **Auto-Scaling**: Horizontal and vertical scaling based on metrics
- **Self-Healing**: Kubernetes health checks and automatic restarts

### 🔒 **Security Benefits**
- **Image Scanning**: Automated vulnerability detection
- **Network Segmentation**: Service mesh and network policies
- **Secrets Management**: Encrypted secrets with Vault

### 📊 **Observability Benefits**
- **Full Stack Monitoring**: Metrics, logs, and traces
- **Alert Management**: Proactive issue detection
- **Performance Insights**: Detailed application metrics

## 🏗️ Architecture Patterns

### 🎯 **Microservices Patterns**
- API Gateway Pattern
- Database per Service
- Saga Pattern for distributed transactions
- Circuit Breaker Pattern

### 🔄 **DevOps Patterns**
- GitOps for deployments
- Infrastructure as Code
- Immutable Infrastructure
- Blue-Green Deployments

### 📊 **Observability Patterns**
- Distributed Tracing
- Centralized Logging
- Metrics Collection
- Health Check Endpoints

## 📚 Documentation

- [Infrastructure Setup](./docs/infrastructure-setup.md)
- [Application Deployment](./docs/application-deployment.md)
- [Monitoring Guide](./docs/monitoring-guide.md)
- [Security Best Practices](./docs/security-guide.md)
- [Troubleshooting](./docs/troubleshooting.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for Production-Grade Kubernetes Deployments**
