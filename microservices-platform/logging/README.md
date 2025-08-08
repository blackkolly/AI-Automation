# Centralized Logging Documentation

## Overview

This directory contains the centralized logging infrastructure using the EFK (Elasticsearch, Fluent Bit, Kibana) stack for the microservices platform. The logging system provides comprehensive log aggregation, processing, and visualization capabilities for all application and infrastructure components.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │───►│   Fluent Bit    │───►│  Elasticsearch  │
│     Logs        │    │ (Log Collector) │    │ (Log Storage &  │
└─────────────────┘    └─────────────────┘    │    Search)      │
                                              └─────────────────┘
┌─────────────────┐    ┌─────────────────┐              │
│  Infrastructure │───►│   Fluent Bit    │──────────────┘
│     Logs        │    │   (DaemonSet)   │
└─────────────────┘    └─────────────────┘              │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Kibana      │◄───┤  Index Management│◄───┤  Elasticsearch  │
│ (Visualization) │    │    & Queries    │    │    Cluster      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Elasticsearch

- **Purpose**: Distributed search and analytics engine for log storage
- **Port**: 9200 (HTTP), 9300 (Transport)
- **Namespace**: logging
- **Storage**: Persistent volumes for data retention

### 2. Fluent Bit

- **Purpose**: Lightweight log processor and forwarder
- **Deployment**: DaemonSet on all nodes
- **Features**: Log parsing, filtering, and routing
- **Memory Footprint**: ~25MB per instance

### 3. Kibana

- **Purpose**: Data visualization and exploration platform
- **Port**: 5601
- **Namespace**: logging
- **Features**: Dashboards, search, and analytics

## Directory Structure

```
logging/
├── README.md                    # This documentation
├── manifests/
│   ├── elasticsearch.yaml      # Elasticsearch deployment
│   ├── fluent-bit.yaml         # Fluent Bit DaemonSet
│   ├── kibana.yaml             # Kibana deployment
│   └── storage.yaml            # Persistent volume claims
├── config/
│   ├── fluent-bit.conf         # Fluent Bit configuration
│   ├── parsers.conf            # Log parsers configuration
│   └── elasticsearch.yml       # Elasticsearch settings
├── kibana/
│   ├── dashboards/             # Pre-built dashboards
│   │   ├── application-logs.json
│   │   ├── kubernetes-logs.json
│   │   └── infrastructure-logs.json
│   ├── index-patterns/         # Index pattern definitions
│   └── visualizations/         # Custom visualizations
├── policies/
│   ├── index-lifecycle.json    # Index lifecycle management
│   └── retention-policy.json   # Log retention policies
└── examples/
    ├── log-formats/            # Example log formats
    └── queries/                # Common Kibana queries
```

## Installation & Setup

### Prerequisites

- Kubernetes cluster with sufficient storage
- kubectl configured
- Persistent volume support (for Elasticsearch)

### Quick Start

1. **Deploy Elasticsearch**:

   ```bash
   kubectl apply -f logging/manifests/storage.yaml
   kubectl apply -f logging/manifests/elasticsearch.yaml
   ```

2. **Deploy Fluent Bit**:

   ```bash
   kubectl apply -f logging/manifests/fluent-bit.yaml
   ```

3. **Deploy Kibana**:

   ```bash
   kubectl apply -f logging/manifests/kibana.yaml
   ```

4. **Verify Installation**:

   ```bash
   kubectl get pods -n logging
   kubectl get services -n logging
   ```

5. **Access Kibana**:

   ```bash
   # Port forward
   kubectl port-forward -n logging service/kibana 5601:5601

   # Open in browser: http://localhost:5601
   ```

### Production Deployment

For production environments:

```bash
# Deploy with high availability
kubectl apply -f logging/manifests/elasticsearch-ha.yaml

# Configure security
kubectl apply -f logging/config/security.yaml

# Set up monitoring
kubectl apply -f logging/monitoring/elasticsearch-exporter.yaml
```

## Configuration

### Fluent Bit Configuration

The main configuration file (`fluent-bit.conf`) defines:

```ini
[SERVICE]
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    Parser            docker
    Tag               kube.*
    Refresh_Interval  5
    Mem_Buf_Limit     50MB

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Merge_Log           On
    K8S-Logging.Parser  On
    K8S-Logging.Exclude Off

[OUTPUT]
    Name            es
    Match           *
    Host            elasticsearch.logging.svc.cluster.local
    Port            9200
    Index           kubernetes
    Type            _doc
    Logstash_Format On
    Logstash_Prefix kubernetes
    Time_Key        @timestamp
    Generate_ID     On
```

### Log Parsing

Common log parsers in `parsers.conf`:

```ini
[PARSER]
    Name        docker
    Format      json
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L
    Time_Keep   On

[PARSER]
    Name        nginx
    Format      regex
    Regex       ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$
    Time_Key    time
    Time_Format %d/%b/%Y:%H:%M:%S %z

[PARSER]
    Name        json
    Format      json
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%S.%L
    Time_Keep   On
```

### Elasticsearch Configuration

Key settings in `elasticsearch.yml`:

```yaml
cluster.name: "kubernetes-logging"
network.host: 0.0.0.0
discovery.seed_hosts: ["elasticsearch-master"]
cluster.initial_master_nodes: ["elasticsearch-master-0"]

# Memory settings
bootstrap.memory_lock: true
ES_JAVA_OPTS: "-Xms2g -Xmx2g"

# Index settings
index.number_of_shards: 1
index.number_of_replicas: 1

# Retention policy
action.auto_create_index: true
action.destructive_requires_name: true
```

## Application Log Integration

### Structured Logging Best Practices

1. **JSON Format**:

   ```json
   {
     "timestamp": "2025-01-15T10:30:00.123Z",
     "level": "INFO",
     "service": "user-service",
     "message": "User created successfully",
     "user_id": "12345",
     "request_id": "req-abc123",
     "trace_id": "trace-def456"
   }
   ```

2. **Log Levels**:
   - `ERROR`: System errors, exceptions
   - `WARN`: Potentially harmful situations
   - `INFO`: General operational messages
   - `DEBUG`: Detailed debugging information

### Language-Specific Examples

#### Node.js (Winston)

```javascript
const winston = require("winston");

const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "app.log" }),
  ],
});

// Usage
logger.info("User login", {
  user_id: "12345",
  ip_address: "192.168.1.1",
  request_id: req.id,
});
```

#### Python (Structlog)

```python
import structlog

logger = structlog.get_logger()

# Usage
logger.info(
    "User created",
    user_id="12345",
    email="user@example.com",
    request_id="req-abc123"
)
```

#### Java (Logback with Logstash Encoder)

```xml
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeContext>true</includeContext>
            <includeMdc>true</includeMdc>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

private static final Logger logger = LoggerFactory.getLogger(UserService.class);

// Usage
MDC.put("user_id", "12345");
MDC.put("request_id", "req-abc123");
logger.info("User operation completed");
MDC.clear();
```

## Kibana Dashboards

### Pre-built Dashboards

1. **Application Logs Dashboard**:

   - Log level distribution
   - Error rate trends
   - Top error messages
   - Service performance metrics

2. **Kubernetes Logs Dashboard**:

   - Pod restart events
   - Node-level statistics
   - Namespace activity
   - Resource utilization logs

3. **Infrastructure Dashboard**:
   - System error patterns
   - Network events
   - Security audit logs
   - Performance bottlenecks

### Custom Visualizations

Common visualization types:

- **Time Series**: Log volume over time
- **Pie Charts**: Log level distribution
- **Data Tables**: Recent error logs
- **Heat Maps**: Error patterns by service
- **Metrics**: Error rates and counts

### Index Patterns

Configure index patterns for different log types:

```
kubernetes-*          # Application and infrastructure logs
nginx-*              # Web server logs
audit-*              # Security audit logs
metrics-*            # Application metrics logs
```

## Log Management

### Index Lifecycle Management

Configure automatic index management:

```json
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_size": "10GB",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "allocate": {
            "number_of_replicas": 0
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "allocate": {
            "number_of_replicas": 0
          }
        }
      },
      "delete": {
        "min_age": "90d"
      }
    }
  }
}
```

### Retention Policies

Configure log retention based on requirements:

- **Application Logs**: 30 days
- **Security Logs**: 90 days
- **Audit Logs**: 1 year
- **Debug Logs**: 7 days

## Search and Analytics

### Common Kibana Queries

1. **Error Logs**:

   ```
   level:ERROR AND @timestamp:[now-1h TO now]
   ```

2. **Specific Service Logs**:

   ```
   kubernetes.labels.app:"user-service" AND level:INFO
   ```

3. **Request Tracing**:

   ```
   request_id:"req-abc123"
   ```

4. **Performance Issues**:
   ```
   message:"slow query" OR response_time:>5000
   ```

### Advanced Search Features

1. **Wildcard Searches**:

   ```
   message:*timeout* OR message:*connection*
   ```

2. **Range Queries**:

   ```
   response_time:[100 TO 500]
   ```

3. **Boolean Logic**:

   ```
   (level:ERROR OR level:WARN) AND service:payment
   ```

4. **Field Existence**:
   ```
   _exists_:error_code
   ```

## Monitoring and Alerting

### Log-based Metrics

Create metrics from logs for alerting:

1. **Error Rate**:

   ```
   count(level:ERROR) / count(*) * 100
   ```

2. **Service Health**:

   ```
   count(service:user-service AND level:ERROR)
   ```

3. **Performance Degradation**:
   ```
   avg(response_time) by service
   ```

### Integration with Prometheus

Export log metrics to Prometheus:

```yaml
# Fluent Bit Prometheus output
[OUTPUT]
    Name        prometheus_exporter
    Match       *
    Host        0.0.0.0
    Port        2021
    Metrics     fluentbit_input_records_total
```

### Alerting Rules

Example Prometheus alerting rules:

```yaml
groups:
  - name: logging.rules
    rules:
      - alert: HighErrorRate
        expr: rate(fluentbit_input_records_total{level="error"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"

      - alert: LogIngestionDown
        expr: up{job="fluent-bit"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Log ingestion is down"
```

## Troubleshooting

### Common Issues

1. **Logs Not Appearing in Kibana**:

   ```bash
   # Check Fluent Bit status
   kubectl logs -n logging daemonset/fluent-bit

   # Verify Elasticsearch connectivity
   kubectl exec -it -n logging fluent-bit-xxx -- curl elasticsearch:9200/_cluster/health

   # Check index creation
   curl http://elasticsearch:9200/_cat/indices?v
   ```

2. **High Memory Usage**:

   ```bash
   # Check Elasticsearch memory
   kubectl top pods -n logging

   # Review index sizes
   curl http://elasticsearch:9200/_cat/indices?v&s=store.size:desc

   # Optimize index settings
   curl -X PUT "elasticsearch:9200/_template/kubernetes" -H 'Content-Type: application/json' -d'
   {
     "index_patterns": ["kubernetes-*"],
     "settings": {
       "number_of_shards": 1,
       "number_of_replicas": 0
     }
   }'
   ```

3. **Slow Search Performance**:

   ```bash
   # Check cluster health
   curl http://elasticsearch:9200/_cluster/health?pretty

   # Review slow queries
   curl http://elasticsearch:9200/_nodes/stats/indices/search?pretty

   # Optimize queries and use time-based indices
   ```

### Performance Optimization

1. **Index Optimization**:

   - Use time-based indices (daily/weekly)
   - Implement proper field mappings
   - Configure appropriate refresh intervals
   - Use index templates

2. **Query Optimization**:

   - Use specific time ranges
   - Filter early in query pipeline
   - Avoid wildcard queries on large datasets
   - Use proper field types

3. **Resource Management**:
   - Configure appropriate JVM heap size
   - Monitor disk space usage
   - Implement proper log rotation
   - Use SSD storage for hot indices

## Security

### Access Control

1. **Elasticsearch Security**:

   ```yaml
   # Enable security features
   xpack.security.enabled: true
   xpack.security.transport.ssl.enabled: true
   xpack.security.http.ssl.enabled: true
   ```

2. **Kibana Authentication**:

   ```yaml
   # Configure authentication
   elasticsearch.username: "kibana_system"
   elasticsearch.password: "${KIBANA_PASSWORD}"
   xpack.security.encryptionKey: "${ENCRYPTION_KEY}"
   ```

3. **Network Policies**:
   ```yaml
   # Restrict network access
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: elasticsearch-network-policy
     namespace: logging
   spec:
     podSelector:
       matchLabels:
         app: elasticsearch
     policyTypes:
       - Ingress
     ingress:
       - from:
           - namespaceSelector:
               matchLabels:
                 name: logging
   ```

### Data Protection

1. **Sensitive Data Filtering**:

   ```ini
   # Fluent Bit filter to remove sensitive data
   [FILTER]
       Name        grep
       Match       *
       Exclude     password|secret|token
   ```

2. **Field Masking**:
   ```ini
   [FILTER]
       Name        modify
       Match       *
       Remove      credit_card
       Remove      ssn
   ```

## Maintenance

### Regular Tasks

1. **Index Management**:

   ```bash
   # Clean old indices
   curl -X DELETE "elasticsearch:9200/kubernetes-$(date -d '30 days ago' +%Y.%m.%d)"

   # Optimize indices
   curl -X POST "elasticsearch:9200/_optimize"

   # Monitor cluster health
   curl http://elasticsearch:9200/_cluster/health?pretty
   ```

2. **Backup Procedures**:

   ```bash
   # Create snapshot repository
   curl -X PUT "elasticsearch:9200/_snapshot/backup" -H 'Content-Type: application/json' -d'
   {
     "type": "fs",
     "settings": {
       "location": "/backup"
     }
   }'

   # Create snapshot
   curl -X PUT "elasticsearch:9200/_snapshot/backup/snapshot_$(date +%Y%m%d)"
   ```

3. **Performance Monitoring**:

   ```bash
   # Monitor Fluent Bit metrics
   curl http://fluent-bit:2020/api/v1/metrics/prometheus

   # Check Elasticsearch performance
   curl http://elasticsearch:9200/_nodes/stats?pretty
   ```

## Integration with Other Tools

### Correlation with Metrics

```yaml
# Add trace context to logs
[FILTER]
    Name        modify
    Match       *
    Add         cluster kubernetes-cluster
    Add         environment production
```

### Alerting Integration

```yaml
# ElastAlert configuration
rules:
  - name: error_spike
    type: spike
    index: kubernetes-*
    num_events: 10
    timeframe:
      minutes: 15
    spike_height: 3
    spike_type: up
    filter:
      - term:
          level: "ERROR"
    alert:
      - slack
```

## Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

## Contributing

When adding new logging components:

1. Update configuration files
2. Add new parsers for custom formats
3. Create relevant Kibana dashboards
4. Document log schema changes
5. Test log flow end-to-end
