# Microservices Platform - Complete Observability Stack

This directory contains a comprehensive enterprise-grade microservices platform with full observability, security, and GitOps capabilities.

## 📁 Directory Structure

```
microservices-local/
├── argocd/                 # GitOps Continuous Deployment
│   ├── install-argocd.sh
│   ├── namespace.yaml
│   └── applications.yaml
├── istio/                  # Service Mesh
│   ├── install-istio.sh
│   ├── gateway.yaml
│   ├── virtual-services.yaml
│   ├── destination-rules.yaml
│   └── security-policies.yaml
├── security/              # Security Policies
│   ├── install-security.sh
│   ├── rbac.yaml
│   ├── network-policies.yaml
│   ├── secrets.yaml
│   ├── pod-security-standards.yaml
│   └── admission-controllers.yaml
├── logging/               # ELK Stack
│   ├── install-elk.sh
│   ├── elasticsearch.yaml
│   ├── kibana.yaml
│   ├── filebeat.yaml
│   ├── logstash.yaml
│   └── log-forwarding.yaml
├── tracing/              # Distributed Tracing
│   ├── install-jaeger.sh
│   ├── jaeger-instance.yaml
│   ├── otel-collector.yaml
│   ├── trace-sampling.yaml
│   └── service-monitors.yaml
└── deploy-platform.sh    # Master deployment script
```

## 🚀 Quick Start

### Prerequisites
- Docker Desktop with Kubernetes enabled
- kubectl configured for your cluster
- Helm 3.x installed

### Complete Platform Deployment

```bash
# Make the master script executable
chmod +x deploy-platform.sh

# Deploy the entire platform
./deploy-platform.sh
```

### Individual Component Deployment

```bash
# 1. GitOps - ArgoCD
cd argocd && ./install-argocd.sh

# 2. Service Mesh - Istio
cd istio && ./install-istio.sh

# 3. Security Components
cd security && ./install-security.sh

# 4. Logging - ELK Stack
cd logging && ./install-elk.sh

# 5. Tracing - Jaeger
cd tracing && ./install-jaeger.sh
```

## 🛠️ Platform Components

### 1. ArgoCD (GitOps)
- **Purpose**: Continuous deployment and GitOps workflow
- **Features**: Application synchronization, rollback capabilities, multi-environment support
- **Access**: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- **Credentials**: admin/admin (change after first login)

### 2. Istio Service Mesh
- **Purpose**: Service-to-service communication, security, traffic management
- **Features**: mTLS, traffic routing, fault injection, observability
- **Components**: Gateway, VirtualServices, DestinationRules, Security Policies

### 3. Security Framework
- **Purpose**: Comprehensive security policies and access control
- **Features**: 
  - RBAC for fine-grained access control
  - Network policies for traffic isolation
  - Pod Security Standards
  - Admission controllers for policy enforcement
  - Secret management

### 4. ELK Stack (Logging)
- **Purpose**: Centralized logging and log analysis
- **Components**:
  - Elasticsearch: Log storage and search
  - Kibana: Log visualization and analysis
  - Filebeat: Log collection from containers
  - Logstash: Log processing and transformation
- **Access**: `kubectl port-forward svc/kibana -n logging 5601:5601`

### 5. Jaeger (Distributed Tracing)
- **Purpose**: Request tracing across microservices
- **Components**:
  - Jaeger Collector: Trace collection
  - Jaeger Query: Trace retrieval and UI
  - OpenTelemetry Collector: Trace processing
  - Sampling configuration for performance optimization
- **Access**: `kubectl port-forward svc/jaeger-query -n observability 16686:16686`

## 🔧 Configuration

### Environment Variables
```bash
# OpenTelemetry configuration for applications
export OTEL_EXPORTER_JAEGER_ENDPOINT=http://jaeger-collector:14268/api/traces
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
export OTEL_SERVICE_NAME=your-service-name
export OTEL_RESOURCE_ATTRIBUTES=service.namespace=microservices
```

### Istio Injection
```bash
# Enable automatic sidecar injection for microservices namespace
kubectl label namespace microservices istio-injection=enabled
```

## 📊 Monitoring and Observability

### Access URLs (after port-forwarding)
- **ArgoCD UI**: https://localhost:8080
- **Kibana**: http://localhost:5601
- **Jaeger UI**: http://localhost:16686
- **Grafana**: http://localhost:3000 (if Prometheus is installed)

### Health Check Commands
```bash
# Check all platform components
kubectl get pods --all-namespaces | grep -E "(argocd|istio|logging|observability)"

# Check ArgoCD applications
kubectl get applications -n argocd

# Check Istio configuration
kubectl get gateway,virtualservice,destinationrule -n microservices

# Check security policies
kubectl get networkpolicies,podsecuritypolicies -n microservices

# Check logging stack
kubectl get pods -n logging

# Check tracing components
kubectl get jaeger,pods -n observability
```

## 🔐 Security Features

### Network Policies
- Default deny-all policy
- Selective allow rules for required communication
- Monitoring namespace access for metrics collection

### RBAC
- Service accounts with minimal required permissions
- Role-based access for different components
- Cluster-level and namespace-level roles

### Pod Security Standards
- Restricted security context requirements
- Non-root user enforcement
- Capability dropping
- Security context validation

## 📝 Application Integration

### Logging Integration
Add to your application containers:
```yaml
env:
- name: LOG_LEVEL
  value: "info"
- name: LOG_FORMAT
  value: "json"
```

### Tracing Integration
For Node.js applications:
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');

const sdk = new NodeSDK({
  instrumentations: [getNodeAutoInstrumentations()],
  traceExporter: new JaegerExporter({
    endpoint: 'http://otel-collector:14268/api/traces',
  }),
});

sdk.start();
```

### Service Mesh Integration
Add Istio annotations to your deployments:
```yaml
metadata:
  annotations:
    sidecar.istio.io/inject: "true"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

## 🚨 Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and node capacity
2. **Services not accessible**: Verify network policies and service configurations
3. **Traces not appearing**: Check OpenTelemetry configuration and collector status
4. **Logs not in Kibana**: Verify Filebeat DaemonSet and Elasticsearch connectivity

### Debug Commands
```bash
# Check pod logs
kubectl logs -f deployment/jaeger-collector -n observability
kubectl logs -f daemonset/filebeat -n logging

# Check service connectivity
kubectl exec -it deployment/api-gateway -n microservices -- curl http://auth-service:3001/health

# Verify Istio configuration
istioctl analyze -n microservices
istioctl proxy-config cluster deployment/api-gateway -n microservices
```

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Istio Documentation](https://istio.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

## 🤝 Contributing

When adding new components:
1. Follow the existing directory structure
2. Include installation scripts with proper error handling
3. Add monitoring and security configurations
4. Update this README with new component information
5. Test the complete deployment flow

## 📋 Next Steps

1. **Deploy Applications**: Use ArgoCD to deploy your microservices
2. **Configure Dashboards**: Set up custom Grafana dashboards for your metrics
3. **Set Up Alerts**: Configure alerting rules for critical metrics
4. **Optimize Performance**: Tune resource limits and scaling policies
5. **Security Hardening**: Review and customize security policies for your requirements
