# Monitoring Stack Documentation

## Overview

This monitoring stack provides comprehensive observability for microservices deployed on EKS with ArgoCD using Prometheus, Grafana, and AlertManager. The stack follows cloud-native best practices and provides automatic service discovery, scalable metrics collection, and professional dashboards.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MONITORING ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                          MICROSERVICES LAYER                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │
│  │ api-gateway │ │auth-service │ │product-svc  │ │ order-svc   │    │
│  │   :3000     │ │   :3001     │ │   :8080     │ │   :3003     │    │
│  │   :9090     │ │   :9090     │ │   :9090     │ │   :9090     │    │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                     SERVICE DISCOVERY LAYER                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   ServiceMonitors                          │    │
│  │  • microservices-monitor (namespace-wide)                  │    │
│  │  • microservices-by-annotation (annotation-based)          │    │
│  │  • api-gateway-monitor (service-specific)                  │    │
│  │  • auth-service-monitor (service-specific)                 │    │
│  │  • product-service-monitor (service-specific)              │    │
│  │  • order-service-monitor (service-specific)                │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                        COLLECTION LAYER                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     Prometheus                              │    │
│  │  • Metrics collection and storage                           │    │
│  │  • Service discovery via Kubernetes API                     │    │
│  │  • Rule evaluation and alerting                             │    │
│  │  • 15-day retention for historical analysis                 │    │
│  └─────────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Node Exporters                              │    │
│  │  • Infrastructure metrics (CPU, Memory, Disk, Network)      │    │
│  │  • Running on all cluster nodes                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │               Kube-State-Metrics                            │    │
│  │  • Kubernetes object state metrics                          │    │
│  │  • Pod, Deployment, Service status                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                      VISUALIZATION LAYER                           │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                       Grafana                               │    │
│  │  • Microservices observability dashboard                    │    │
│  │  • Infrastructure monitoring dashboards                     │    │
│  │  • Real-time alerting and notifications                     │    │
│  │  • Custom dashboard provisioning                            │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                        ALERTING LAYER                              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   AlertManager                              │    │
│  │  • Alert routing and grouping                               │    │
│  │  • Notification channels (Email, Slack, PagerDuty)         │    │
│  │  • Silence and inhibition rules                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### Prometheus Stack

- **Prometheus Server**: Metrics collection, storage, and querying
- **Prometheus Operator**: Manages Prometheus deployments and configurations
- **Grafana**: Visualization and dashboarding platform
- **AlertManager**: Alert routing and notification management
- **Node Exporters**: Infrastructure metrics collection
- **Kube-State-Metrics**: Kubernetes state metrics

### Custom Components

- **ServiceMonitors**: Automatic service discovery configurations
- **Custom Dashboards**: Microservices-specific monitoring dashboards
- **Metrics Templates**: Node.js application instrumentation templates

## Deployment Options

### 🌩️ AWS EKS Deployment (Previous)

All AWS resources have been successfully destroyed to avoid charges.

### 🖥️ Local Docker Desktop Deployment (Current)

Run the entire platform locally for **FREE** using Docker Desktop Kubernetes!

#### Quick Start

```bash
# Deploy everything locally
./deploy-local.sh

# Access your services
Grafana:      http://localhost:30300 (admin / prom-operator)
Prometheus:   http://localhost:30090
Jaeger UI:    http://localhost:30686
API Gateway:  http://localhost:30000
```

#### Current Local Status

```bash
# After running deploy-local.sh, you'll have:
✅ Prometheus Server (monitoring metrics collection)
✅ Grafana (dashboards and visualization)
✅ AlertManager (alert routing and notifications)
✅ Jaeger (distributed tracing)
✅ All 4 microservices with metrics endpoints
✅ ServiceMonitors for automatic service discovery
```

### ServiceMonitors

```bash
# Automatic service discovery configured
✅ microservices-monitor (namespace-wide discovery)
✅ microservices-by-annotation (annotation-based discovery)
✅ api-gateway-monitor (service-specific monitoring)
✅ auth-service-monitor (service-specific monitoring)
✅ product-service-monitor (service-specific monitoring)
✅ order-service-monitor (service-specific monitoring)
```

## Access Methods

## Access Methods

### Method 1: Local NodePort Services (Recommended for Local)

```bash
# Direct access via NodePort services
Prometheus: http://localhost:30090
Grafana: http://localhost:30300
AlertManager: http://localhost:30903
Jaeger UI: http://localhost:30686
API Gateway: http://localhost:30000
```

### Method 2: Port Forwarding (Alternative)

```bash
# Start port forwards
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus -n monitoring 9090:9090 &
kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80 &
kubectl port-forward svc/prometheus-stack-kube-prom-alertmanager -n monitoring 9093:9093 &

# Access URLs
Prometheus: http://localhost:9090
Grafana: http://localhost:3000
AlertManager: http://localhost:9093
```

### Method 3: Automation Script

```bash
# Deploy everything locally
./deploy-local.sh

# Cleanup everything
./cleanup-local.sh
```

## Key Features

### 1. Automatic Service Discovery

- **ServiceMonitor CRDs**: Automatically discover and monitor services
- **Label-based Discovery**: Services with `monitoring=prometheus` label
- **Annotation-based Discovery**: Services with Prometheus annotations
- **Dynamic Configuration**: No manual target configuration required

### 2. Comprehensive Metrics Collection

```bash
# Infrastructure Metrics
- CPU usage, memory consumption, disk I/O
- Network traffic, filesystem usage
- Pod and container resource utilization

# Kubernetes Metrics
- Pod status, deployment health
- Service availability, endpoint status
- Resource quotas and limits

# Application Metrics (when implemented)
- HTTP request rates and latency
- Error rates and response codes
- Custom business metrics
```

### 3. Professional Dashboards

- **Microservices Dashboard**: Service health, performance, and resource usage
- **Infrastructure Dashboards**: Node health, cluster overview
- **Kubernetes Dashboards**: Pod status, deployment health
- **Custom Dashboards**: Business-specific KPIs

### 4. Intelligent Alerting

- **Threshold-based Alerts**: CPU, memory, disk usage
- **Rate-based Alerts**: Error rates, latency increases
- **Availability Alerts**: Service downtime, pod failures
- **Custom Alerts**: Business-specific conditions

## Microservices Integration

### Current State

Your microservices are configured with:

- ✅ **Monitoring Labels**: Applied to all services
- ✅ **ServiceMonitors**: Created for automatic discovery
- ✅ **Resource Monitoring**: Pod and container metrics collected
- 🔄 **Application Metrics**: Ready for implementation

### Adding Application Metrics

1. **Install Prometheus Client**:

   ```bash
   npm install prom-client
   ```

2. **Use the Metrics Template**:

   ```javascript
   // Copy monitoring/nodejs-metrics-template.js to your app
   const { metricsMiddleware, startMetricsServer } = require("./metrics");

   const app = express();
   const serviceName = process.env.SERVICE_NAME || "my-service";

   // Add metrics middleware
   app.use(metricsMiddleware(serviceName));

   // Start metrics server
   if (process.env.ENABLE_METRICS === "true") {
     startMetricsServer(9090);
   }
   ```

3. **Environment Variables**:
   ```yaml
   env:
     - name: ENABLE_METRICS
       value: "true"
     - name: METRICS_PORT
       value: "9090"
     - name: SERVICE_NAME
       value: "api-gateway"
   ```

## Credentials

| Service      | Username | Password      | Notes                          |
| ------------ | -------- | ------------- | ------------------------------ |
| Grafana      | admin    | prom-operator | Default Helm chart credentials |
| Prometheus   | -        | No auth       | Internal service               |
| AlertManager | -        | No auth       | Internal service               |

## Directory Structure

```
monitoring/
├── README.md                           # This comprehensive documentation
├── prometheus.yml                      # Prometheus configuration
├── external-services.yaml              # LoadBalancer services
├── microservices-servicemonitor.yaml   # ServiceMonitor configurations
├── configure-microservices-metrics.sh  # Metrics configuration script
├── check-observability-status.sh       # Status check script
├── nodejs-metrics-template.js          # Node.js metrics template
├── grafana/
│   └── dashboards/
│       └── microservices-dashboard.yaml # Custom Grafana dashboard
└── alerts/
    ├── rules.yml                       # Prometheus alerting rules
    └── alertmanager.yml                # AlertManager configuration
```

## Troubleshooting

### Common Issues

1. **Services Not Discovered**:

   ```bash
   # Check ServiceMonitor status
   kubectl get servicemonitor -n monitoring
   kubectl describe servicemonitor microservices-monitor -n monitoring

   # Verify service labels
   kubectl get services -n microservices -l monitoring=prometheus

   # Check Prometheus targets
   # Access http://localhost:9090/targets
   ```

2. **No Metrics Data**:

   ```bash
   # Check if services expose /metrics endpoint
   kubectl port-forward svc/api-gateway -n microservices 3000:3000
   curl http://localhost:3000/metrics

   # Verify ServiceMonitor configuration
   kubectl get servicemonitor -o yaml
   ```

3. **Dashboard Not Loading**:

   ```bash
   # Check Grafana pod status
   kubectl get pods -n monitoring | grep grafana
   kubectl logs prometheus-stack-grafana-xxx -n monitoring

   # Verify dashboard ConfigMap
   kubectl get configmap microservices-dashboard -n monitoring
   ```

## Performance Optimization

1. **Reduce Scrape Frequency**:

   ```yaml
   endpoints:
     - interval: 60s # Increase from 30s for less load
   ```

2. **Filter Unnecessary Metrics**:
   ```yaml
   metricRelabelings:
     - sourceLabels: [__name__]
       regex: "unwanted_metric_.*"
       action: drop
   ```

## Best Practices

### Application Integration

1. **Implement Custom Metrics**: Track business KPIs and application-specific metrics
2. **Use Structured Labels**: Consistent labeling for better aggregation
3. **Monitor SLIs/SLOs**: Track service level indicators and objectives
4. **Resource Monitoring**: Track resource usage to optimize performance

### Dashboard Design

1. **Group Related Metrics**: Organize dashboards by service or function
2. **Use Meaningful Time Ranges**: Default to relevant time windows
3. **Add Context**: Include annotations and descriptions
4. **Implement Templating**: Use variables for dynamic dashboards

### Alerting Strategy

1. **Define Clear Severity Levels**: Critical, Warning, Info
2. **Avoid Alert Fatigue**: Set appropriate thresholds
3. **Implement Escalation**: Progressive alert escalation
4. **Regular Testing**: Test alert delivery regularly

## Maintenance Tasks

### Daily

- [ ] Monitor dashboards for anomalies
- [ ] Review alert notifications
- [ ] Check resource usage trends

### Weekly

- [ ] Review and tune alerting rules
- [ ] Analyze performance trends
- [ ] Update dashboard configurations

### Monthly

- [ ] Review retention policies
- [ ] Update component versions
- [ ] Performance optimization review
- [ ] Backup important configurations

## Support and Resources

### Quick Commands

```bash
# Check monitoring stack status
kubectl get all -n monitoring

# Access services locally
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus -n monitoring 9090:9090 &
kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80 &

# Check ServiceMonitor status
kubectl get servicemonitor -n monitoring

# Run status check script
./check-observability-status.sh
```

### Useful Queries

#### Prometheus Queries (PromQL)

```bash
# CPU usage by pod
rate(container_cpu_usage_seconds_total{namespace="microservices"}[5m])

# Memory usage by service
container_memory_usage_bytes{namespace="microservices",container!="POD"}

# HTTP request rate
rate(http_requests_total{namespace="microservices"}[5m])

# Error rate percentage
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
```

### Resources

- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **ServiceMonitor Guide**: https://github.com/prometheus-operator/prometheus-operator
- **PromQL Tutorial**: https://prometheus.io/docs/prometheus/latest/querying/

---

**Status**: ✅ **FULLY OPERATIONAL**  
**Last Updated**: August 3, 2025  
**Cluster**: EKS with ArgoCD  
**Monitoring Stack**: Prometheus + Grafana + AlertManager  
**Services Monitored**: api-gateway, auth-service, product-service, order-service

# Get external IPs

kubectl get services -n monitoring | grep LoadBalancer

# Access URLs

# Grafana: http://<EXTERNAL-IP>:3000

# Prometheus: http://<EXTERNAL-IP>:9090

# AlertManager: http://<EXTERNAL-IP>:9093

````

#### Method 2: Port Forwarding (Local Access)
```bash
# Grafana
kubectl port-forward -n monitoring service/prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring service/prometheus-stack-kube-prom-prometheus 9090:9090

# AlertManager
kubectl port-forward -n monitoring service/prometheus-stack-kube-prom-alertmanager 9093:9093
````

#### Method 3: Automated Script

```bash
# Use the provided automation script
./start-observability.sh
```

## Configuration

### Prometheus Configuration (`prometheus.yml`)

The Prometheus configuration defines:

- Scrape intervals and timeouts
- Service discovery rules
- Target endpoints for metrics collection
- Recording and alerting rules

Key sections:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "kubernetes-pods"
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### Grafana Dashboards

Pre-configured dashboards include:

1. **Cluster Overview**

   - CPU, Memory, and Disk usage
   - Pod and Node status
   - Network I/O metrics

2. **Microservices Dashboard**

   - Application-specific metrics
   - Request rates and latencies
   - Error rates and status codes

3. **Node Metrics**
   - System-level metrics
   - Hardware utilization
   - Network and disk performance

### AlertManager Rules

Common alerting rules:

- High CPU/Memory usage
- Pod restart loops
- Service downtime
- Disk space warnings

## Monitoring Best Practices

### 1. Metrics Collection

- Use Prometheus client libraries in applications
- Implement custom metrics for business logic
- Follow naming conventions (snake_case)
- Use appropriate metric types (counter, gauge, histogram)

### 2. Dashboard Design

- Group related metrics together
- Use consistent time ranges
- Implement proper templating
- Add meaningful annotations

### 3. Alerting Strategy

- Define clear severity levels
- Avoid alert fatigue
- Implement escalation policies
- Test alert delivery regularly

## Troubleshooting

### Common Issues

1. **Prometheus Not Scraping Targets**

   ```bash
   # Check target discovery
   kubectl logs -n monitoring prometheus-stack-kube-prom-prometheus-0

   # Verify service discovery
   kubectl get endpoints -n monitoring
   ```

2. **Grafana Dashboard Not Loading**

   ```bash
   # Check Grafana logs
   kubectl logs -n monitoring deployment/prometheus-stack-grafana

   # Verify datasource connection
   # Go to Grafana → Configuration → Data Sources
   ```

3. **High Memory Usage**

   ```bash
   # Check Prometheus retention settings
   kubectl describe statefulset -n monitoring prometheus-stack-kube-prom-prometheus

   # Adjust retention period if needed
   ```

### Performance Optimization

1. **Reduce Cardinality**:

   - Limit label values
   - Use recording rules for complex queries
   - Implement metric filtering

2. **Storage Management**:

   - Configure appropriate retention periods
   - Use remote storage for long-term retention
   - Implement data compaction

3. **Query Optimization**:
   - Use efficient PromQL queries
   - Implement proper time ranges
   - Cache frequently used queries

## Metrics Reference

### Application Metrics

- `http_requests_total`: Total HTTP requests
- `http_request_duration_seconds`: Request latency
- `http_request_size_bytes`: Request payload size
- `http_response_size_bytes`: Response payload size

### Infrastructure Metrics

- `node_cpu_seconds_total`: CPU usage
- `node_memory_MemTotal_bytes`: Total memory
- `node_filesystem_size_bytes`: Filesystem size
- `node_network_receive_bytes_total`: Network RX bytes

### Kubernetes Metrics

- `kube_pod_status_phase`: Pod status
- `kube_deployment_status_replicas`: Deployment replicas
- `kube_service_info`: Service information
- `kube_namespace_status_phase`: Namespace status

## Security Considerations

1. **Access Control**:

   - Use RBAC for service accounts
   - Implement network policies
   - Secure Grafana with proper authentication

2. **Data Protection**:

   - Encrypt metrics in transit
   - Secure storage backends
   - Implement audit logging

3. **Secret Management**:
   - Use Kubernetes secrets for credentials
   - Rotate passwords regularly
   - Implement least privilege access

## Maintenance

### Regular Tasks

- Update Helm charts monthly
- Review and update alerting rules
- Clean up old metrics data
- Backup Grafana dashboards

### Monitoring Health Checks

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify AlertManager status
curl http://localhost:9093/api/v1/status

# Test Grafana API
curl http://admin:admin123@localhost:3000/api/health
```

## Integration with Other Components

### Logging Integration

- Correlate metrics with log events
- Use consistent labeling across systems
- Implement log-based metrics

### Tracing Integration

- Connect metrics to trace spans
- Monitor trace sampling rates
- Track distributed system health

### CI/CD Integration

- Monitor deployment metrics
- Track application performance over releases
- Implement automated rollback triggers

## Support & Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Kubernetes Monitoring Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)

## Contributing

When adding new monitoring components:

1. Update this documentation
2. Add appropriate alerting rules
3. Create or update Grafana dashboards
4. Test metric collection and visualization
5. Document any new dependencies or requirements
