# Observability Stack Documentation

## Overview

This document provides a comprehensive guide to the observability stack implemented for the microservices platform. The stack follows the three pillars of observability: **Monitoring**, **Logging**, and **Tracing**, providing complete visibility into application performance, behavior, and issues.

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                 Observability Stack                     │
                    └─────────────────────────────────────────────────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────────┐
                    │                         │                             │
            ┌───────▼────────┐       ┌───────▼────────┐            ┌───────▼────────┐
            │   MONITORING   │       │    LOGGING     │            │    TRACING     │
            │                │       │                │            │                │
            │   Prometheus   │       │ Elasticsearch  │            │     Jaeger     │
            │    Grafana     │       │   Fluent Bit   │            │ (All-in-One)   │
            │ AlertManager   │       │     Kibana     │            │                │
            └────────────────┘       └────────────────┘            └────────────────┘
                    │                         │                             │
            ┌───────▼────────┐       ┌───────▼────────┐            ┌───────▼────────┐
            │ Metrics & KPIs │       │ Centralized    │            │ Request Flows  │
            │   Dashboards   │       │     Logs       │            │ & Dependencies │
            │    Alerting    │       │   Search &     │            │   Performance  │
            │               │        │   Analytics    │            │    Debug       │
            └────────────────┘       └────────────────┘            └────────────────┘
```

## Components Summary

| Component         | Purpose                       | Access     | Namespace  |
| ----------------- | ----------------------------- | ---------- | ---------- |
| **Prometheus**    | Metrics collection & storage  | Port 9090  | monitoring |
| **Grafana**       | Metrics visualization         | Port 3000  | monitoring |
| **AlertManager**  | Alert routing & notifications | Port 9093  | monitoring |
| **Elasticsearch** | Log storage & search          | Port 9200  | logging    |
| **Fluent Bit**    | Log collection & processing   | DaemonSet  | logging    |
| **Kibana**        | Log visualization & analytics | Port 5601  | logging    |
| **Jaeger**        | Distributed tracing           | Port 16686 | monitoring |

## Quick Start Guide

### 1. Prerequisites

- Kubernetes cluster (EKS/GKE/AKS)
- kubectl configured and connected
- Helm 3.x installed
- Sufficient cluster resources (4+ nodes recommended)

### 2. Deployment Order

```bash
# 1. Deploy monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# 2. Deploy logging stack
kubectl apply -f logging/manifests/

# 3. Deploy tracing stack
kubectl apply -f tracing/manifests/jaeger.yaml

# 4. Apply external services for LoadBalancer access
kubectl apply -f monitoring/external-services.yaml
```

### 3. Access Methods

#### Option A: LoadBalancer URLs (External Access)

```bash
# Get external IPs
kubectl get services -n monitoring -o wide | grep LoadBalancer
kubectl get services -n logging -o wide | grep LoadBalancer

# Access via browser:
# Grafana: http://<GRAFANA-EXTERNAL-IP>:3000
# Prometheus: http://<PROMETHEUS-EXTERNAL-IP>:9090
# AlertManager: http://<ALERTMANAGER-EXTERNAL-IP>:9093
# Kibana: http://<KIBANA-EXTERNAL-IP>:5601
# Jaeger: http://<JAEGER-EXTERNAL-IP>:16686
```

#### Option B: Port Forwarding (Local Access)

```bash
# Use the automation script
./start-observability.sh

# Or manually:
kubectl port-forward -n monitoring service/prometheus-stack-grafana 3000:80 &
kubectl port-forward -n monitoring service/prometheus-stack-kube-prom-prometheus 9090:9090 &
kubectl port-forward -n monitoring service/prometheus-stack-kube-prom-alertmanager 9093:9093 &
kubectl port-forward -n logging service/kibana 5601:5601 &
kubectl port-forward -n monitoring service/jaeger-query 16686:16686 &
```

#### Option C: VS Code Simple Browser

```bash
# Access via VS Code's integrated browser
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
# AlertManager: http://localhost:9093
# Kibana: http://localhost:5601
# Jaeger: http://localhost:16686
```

### 4. Default Credentials

| Service        | Username | Password          |
| -------------- | -------- | ----------------- |
| Grafana        | admin    | admin123          |
| Kibana         | -        | No authentication |
| Other services | -        | No authentication |

## Directory Structure

```
microservices-platform/
├── monitoring/                 # Prometheus, Grafana, AlertManager
│   ├── README.md              # Detailed monitoring documentation
│   ├── prometheus.yml         # Prometheus configuration
│   ├── external-services.yaml # LoadBalancer services
│   ├── grafana/              # Grafana configurations
│   │   ├── dashboards/       # Pre-built dashboards
│   │   └── provisioning/     # Auto-provisioning configs
│   └── alerts/               # Alerting rules and config
│       ├── rules.yml         # Prometheus alerting rules
│       └── alertmanager.yml  # AlertManager configuration
│
├── logging/                   # EFK Stack (Elasticsearch, Fluent Bit, Kibana)
│   ├── README.md             # Detailed logging documentation
│   ├── manifests/            # Kubernetes manifests
│   ├── config/               # Configuration files
│   │   ├── fluent-bit.conf   # Fluent Bit configuration
│   │   ├── parsers.conf      # Log parsers
│   │   └── elasticsearch.yml # Elasticsearch settings
│   ├── kibana/              # Kibana configurations
│   └── policies/            # Index lifecycle policies
│
├── tracing/                  # Jaeger distributed tracing
│   ├── README.md            # Detailed tracing documentation
│   ├── manifests/           # Kubernetes manifests
│   │   ├── jaeger.yaml      # All-in-one deployment
│   │   └── jaeger-production.yaml # Production setup
│   ├── config/              # Configuration files
│   │   └── sampling-strategies.json # Sampling config
│   ├── instrumentation/     # Code examples
│   │   ├── nodejs/          # Node.js instrumentation
│   │   ├── python/          # Python instrumentation
│   │   ├── java/            # Java instrumentation
│   │   └── golang/          # Go instrumentation
│   └── examples/            # Sample applications
│
└── start-observability.sh    # Automation script for port-forwards
```

## Key Features

### Monitoring (Prometheus + Grafana)

- **Real-time Metrics**: CPU, memory, disk, network, application metrics
- **Custom Dashboards**: Service-specific and infrastructure dashboards
- **Alerting**: Automated alerts for critical conditions
- **Historical Data**: 15-day retention for trend analysis
- **Service Discovery**: Automatic target discovery in Kubernetes

### Logging (EFK Stack)

- **Centralized Logs**: All application and infrastructure logs in one place
- **Structured Logging**: JSON format support with custom parsers
- **Search & Analytics**: Full-text search and log analytics
- **Index Management**: Automated lifecycle and retention policies
- **Real-time Processing**: Low-latency log ingestion and processing

### Tracing (Jaeger)

- **Distributed Tracing**: End-to-end request flow visualization
- **Performance Analysis**: Latency analysis and bottleneck identification
- **Dependency Mapping**: Service interaction visualization
- **Error Tracking**: Exception tracking across services
- **Sampling Control**: Configurable sampling strategies

## Integration & Correlation

### Metrics ↔ Logs

- **Log-based Metrics**: Generate metrics from log patterns
- **Alert Correlation**: Link alerts to relevant log entries
- **Dashboard Integration**: Embedded log queries in Grafana

### Metrics ↔ Traces

- **Performance Correlation**: Link slow requests to trace details
- **Service Health**: Correlate service metrics with trace data
- **SLI/SLO Tracking**: Use traces for service level indicators

### Logs ↔ Traces

- **Context Propagation**: Trace IDs in log entries
- **Root Cause Analysis**: Navigate from logs to traces
- **Error Investigation**: Link error logs to trace spans

## Common Use Cases

### 1. Performance Monitoring

```bash
# Monitor application performance
# Grafana → Application Dashboard → Response Time Panel
# Check 95th percentile latency trends
```

### 2. Error Investigation

```bash
# Step 1: Check error rate in Grafana
# Step 2: Search error logs in Kibana
# Step 3: Find trace ID in logs
# Step 4: Open trace in Jaeger for detailed analysis
```

### 3. Capacity Planning

```bash
# Prometheus → Resource utilization queries
# Grafana → Infrastructure dashboards
# Historical data analysis for growth trends
```

### 4. Troubleshooting Service Issues

```bash
# Step 1: Check service health metrics (Grafana)
# Step 2: Review recent error logs (Kibana)
# Step 3: Analyze slow requests (Jaeger)
# Step 4: Correlate with infrastructure metrics
```

## Best Practices

### Application Integration

1. **Metrics**: Implement custom metrics for business KPIs

   ```javascript
   // Example: Track user registrations
   const userRegistrations = new prometheus.Counter({
     name: "user_registrations_total",
     help: "Total number of user registrations",
   });
   ```

2. **Logging**: Use structured logging with consistent fields

   ```json
   {
     "timestamp": "2025-01-15T10:30:00Z",
     "level": "INFO",
     "service": "user-service",
     "request_id": "req-123",
     "trace_id": "trace-456",
     "message": "User created successfully"
   }
   ```

3. **Tracing**: Add meaningful spans and attributes
   ```javascript
   const span = tracer.startSpan("database_query");
   span.setTag("db.type", "postgresql");
   span.setTag("db.statement", "SELECT * FROM users WHERE id = ?");
   ```

### Operational Excellence

1. **Alerting Strategy**:

   - Define clear severity levels (Critical, Warning, Info)
   - Avoid alert fatigue with proper thresholds
   - Implement escalation policies
   - Test alert delivery regularly

2. **Dashboard Design**:

   - Group related metrics together
   - Use consistent time ranges
   - Add meaningful annotations
   - Implement proper templating

3. **Log Management**:
   - Configure appropriate retention periods
   - Use index lifecycle management
   - Implement log sampling for high-volume services
   - Regular index optimization

## Troubleshooting

### Common Issues

1. **Services Not Accessible**:

   ```bash
   # Check service status
   kubectl get pods -n monitoring
   kubectl get services -n monitoring

   # Check port-forwards
   ps aux | grep "kubectl port-forward"

   # Restart port-forwards
   ./start-observability.sh
   ```

2. **No Metrics/Logs/Traces**:

   ```bash
   # Check agent connectivity
   kubectl logs -n monitoring daemonset/fluent-bit
   kubectl logs -n monitoring daemonset/jaeger-agent

   # Verify configurations
   kubectl describe configmap -n monitoring
   ```

3. **High Resource Usage**:

   ```bash
   # Monitor resource consumption
   kubectl top pods -n monitoring
   kubectl top pods -n logging

   # Adjust resource limits if needed
   ```

### Performance Optimization

1. **Reduce Data Volume**:

   - Implement sampling strategies
   - Configure retention policies
   - Use efficient queries
   - Filter unnecessary data

2. **Scale Components**:
   - Horizontal scaling for collectors
   - Vertical scaling for storage
   - Load balancing for queries
   - Proper resource allocation

## Maintenance Tasks

### Daily

- Monitor cluster health dashboards
- Check alert notifications
- Review error logs for anomalies

### Weekly

- Analyze performance trends
- Review and update alerting rules
- Clean up old indices/metrics

### Monthly

- Update component versions
- Review and optimize queries
- Backup important dashboards
- Performance tuning analysis

## Security Considerations

1. **Access Control**:

   - Implement RBAC for service accounts
   - Use network policies for isolation
   - Secure external access with authentication

2. **Data Protection**:

   - Encrypt data in transit and at rest
   - Sanitize sensitive information in logs
   - Implement audit logging

3. **Network Security**:
   - Use TLS for all communications
   - Restrict network access with policies
   - Monitor for security events

## Support Resources

- **Documentation**: Each component has detailed README files
- **Examples**: Sample configurations and code in respective directories
- **Scripts**: Automation scripts for common tasks
- **Troubleshooting**: Component-specific troubleshooting guides

## Contributing

When making changes to the observability stack:

1. **Update Documentation**: Keep README files current
2. **Test Changes**: Validate in development environment
3. **Version Control**: Tag configuration changes
4. **Monitor Impact**: Watch for performance effects
5. **Document Decisions**: Record architectural decisions

---

For detailed component-specific information, refer to:

- [Monitoring Documentation](./monitoring/README.md)
- [Logging Documentation](./logging/README.md)
- [Tracing Documentation](./tracing/README.md)
