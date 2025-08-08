# Distributed Tracing Documentation

## Overview

This directory contains the distributed tracing infrastructure using Jaeger for the microservices platform. Distributed tracing provides end-to-end visibility into request flows across microservices, enabling performance analysis, dependency mapping, and root cause analysis for complex distributed systems.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │───►│  Jaeger Agent   │───►│ Jaeger Collector│
│   (Instrumented)│    │   (Sidecar)     │    │  (Aggregation)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Jaeger UI     │◄───┤ Jaeger Query    │◄───┤  Storage Layer  │
│  (Visualization)│    │   (API Server)  │    │ (Elasticsearch) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Jaeger All-in-One

- **Purpose**: Complete tracing solution in single deployment
- **UI Port**: 16686
- **Collector Ports**: 14268 (HTTP), 14250 (gRPC)
- **Agent Ports**: 6831 (UDP), 6832 (UDP), 5778 (HTTP)
- **Namespace**: monitoring

### 2. Jaeger Agent

- **Purpose**: Local agent for trace collection from applications
- **Deployment**: Sidecar or DaemonSet
- **Protocol**: UDP/HTTP for trace reception

### 3. Jaeger Collector

- **Purpose**: Receives traces from agents and stores them
- **Features**: Validation, indexing, and storage
- **Scaling**: Horizontal scaling support

### 4. Jaeger Query & UI

- **Purpose**: Web interface for trace visualization and search
- **Features**: Trace timeline, service map, dependency analysis
- **Access**: Web browser interface

## Directory Structure

```
tracing/
├── README.md                    # This documentation
├── manifests/
│   ├── jaeger.yaml             # Jaeger all-in-one deployment
│   ├── jaeger-production.yaml  # Production-ready setup
│   └── jaeger-operator.yaml    # Jaeger Operator deployment
├── instrumentation/
│   ├── java/                   # Java application examples
│   ├── nodejs/                 # Node.js application examples
│   ├── python/                 # Python application examples
│   └── golang/                 # Go application examples
├── config/
│   ├── jaeger-config.yaml      # Jaeger configuration
│   └── sampling-strategies.json # Sampling configuration
└── examples/
    ├── simple-service/         # Example instrumented service
    └── microservice-chain/     # Multi-service trace example
```

## Installation & Setup

### Prerequisites

- Kubernetes cluster
- kubectl configured
- Applications instrumented with OpenTracing/OpenTelemetry

### Quick Start

1. **Deploy Jaeger All-in-One**:

   ```bash
   kubectl apply -f tracing/manifests/jaeger.yaml
   ```

2. **Verify Installation**:

   ```bash
   kubectl get pods -n monitoring | grep jaeger
   kubectl get services -n monitoring | grep jaeger
   ```

3. **Access Jaeger UI**:

   ```bash
   # Port forward
   kubectl port-forward -n monitoring service/jaeger-query 16686:16686

   # Or use LoadBalancer service (if deployed)
   kubectl get service jaeger-query-lb -n monitoring
   ```

### Production Deployment

For production environments, use the production-ready configuration:

```bash
# Deploy with proper resource limits and persistence
kubectl apply -f tracing/manifests/jaeger-production.yaml

# Enable TLS and authentication
kubectl apply -f tracing/config/jaeger-config.yaml
```

## Application Instrumentation

### Node.js Example

1. **Install Dependencies**:

   ```bash
   npm install jaeger-client opentracing
   ```

2. **Initialize Tracer**:

   ```javascript
   const initTracer = require("jaeger-client").initTracer;
   const opentracing = require("opentracing");

   const config = {
     serviceName: "my-service",
     sampler: {
       type: "const",
       param: 1,
     },
     reporter: {
       agentHost: "jaeger-agent",
       agentPort: 6832,
     },
   };

   const tracer = initTracer(config);
   opentracing.setGlobalTracer(tracer);
   ```

3. **Create Spans**:

   ```javascript
   const express = require("express");
   const app = express();

   app.get("/api/users", (req, res) => {
     const span = tracer.startSpan("get_users");
     span.setTag("http.method", "GET");
     span.setTag("http.url", "/api/users");

     // Business logic here
     getUsersFromDatabase()
       .then((users) => {
         span.setTag("user.count", users.length);
         res.json(users);
         span.finish();
       })
       .catch((error) => {
         span.setTag("error", true);
         span.log({ event: "error", message: error.message });
         span.finish();
         res.status(500).json({ error: "Internal Server Error" });
       });
   });
   ```

### Python Example

1. **Install Dependencies**:

   ```bash
   pip install jaeger-client opentracing
   ```

2. **Initialize Tracer**:

   ```python
   from jaeger_client import Config
   from opentracing import set_global_tracer

   config = Config(
       config={
           'sampler': {'type': 'const', 'param': 1},
           'logging': True,
           'reporter': {
               'host': 'jaeger-agent',
               'port': 6832,
           }
       },
       service_name='my-python-service'
   )

   tracer = config.initialize_tracer()
   set_global_tracer(tracer)
   ```

3. **Create Spans**:

   ```python
   from flask import Flask
   from opentracing import get_global_tracer

   app = Flask(__name__)
   tracer = get_global_tracer()

   @app.route('/api/data')
   def get_data():
       with tracer.start_span('get_data') as span:
           span.set_tag('http.method', 'GET')
           span.set_tag('http.url', '/api/data')

           try:
               data = fetch_data_from_service()
               span.set_tag('data.count', len(data))
               return jsonify(data)
           except Exception as e:
               span.set_tag('error', True)
               span.log_kv({'event': 'error', 'message': str(e)})
               raise
   ```

### Java Example

1. **Add Dependencies** (Maven):

   ```xml
   <dependency>
       <groupId>io.jaegertracing</groupId>
       <artifactId>jaeger-client</artifactId>
       <version>1.8.1</version>
   </dependency>
   ```

2. **Initialize Tracer**:

   ```java
   import io.jaegertracing.Configuration;
   import io.opentracing.Tracer;
   import io.opentracing.util.GlobalTracer;

   Configuration config = Configuration.fromEnv("my-java-service");
   Tracer tracer = config.getTracer();
   GlobalTracer.registerIfAbsent(tracer);
   ```

3. **Create Spans**:

   ```java
   import io.opentracing.Span;
   import io.opentracing.Tracer;
   import io.opentracing.util.GlobalTracer;

   @RestController
   public class UserController {
       private final Tracer tracer = GlobalTracer.get();

       @GetMapping("/api/users")
       public ResponseEntity<List<User>> getUsers() {
           Span span = tracer.buildSpan("get_users").start();
           span.setTag("http.method", "GET");
           span.setTag("http.url", "/api/users");

           try {
               List<User> users = userService.getAllUsers();
               span.setTag("user.count", users.size());
               return ResponseEntity.ok(users);
           } catch (Exception e) {
               span.setTag("error", true);
               span.log(Map.of("event", "error", "message", e.getMessage()));
               throw e;
           } finally {
               span.finish();
           }
       }
   }
   ```

## Configuration

### Sampling Strategies

Configure sampling to control trace volume:

```json
{
  "service_strategies": [
    {
      "service": "high-volume-service",
      "type": "probabilistic",
      "param": 0.1
    },
    {
      "service": "critical-service",
      "type": "const",
      "param": 1
    }
  ],
  "default_strategy": {
    "type": "probabilistic",
    "param": 0.5
  }
}
```

### Environment Variables

Common configuration options:

```yaml
env:
  - name: JAEGER_AGENT_HOST
    value: "jaeger-agent"
  - name: JAEGER_AGENT_PORT
    value: "6832"
  - name: JAEGER_SAMPLER_TYPE
    value: "const"
  - name: JAEGER_SAMPLER_PARAM
    value: "1"
  - name: JAEGER_SERVICE_NAME
    value: "my-service"
```

## Best Practices

### 1. Span Design

- Use meaningful operation names
- Add relevant tags and logs
- Keep span hierarchies logical
- Minimize span creation overhead

### 2. Sampling Strategy

- Use probabilistic sampling for high-volume services
- Sample 100% for critical paths
- Adjust sampling based on traffic patterns
- Monitor sampling effectiveness

### 3. Tag Strategy

- Use consistent tag naming
- Include relevant business context
- Add error information when applicable
- Avoid high-cardinality tags

### 4. Performance Considerations

- Use asynchronous reporting
- Implement proper buffering
- Monitor trace overhead
- Optimize instrumentation points

## Trace Analysis

### Common Use Cases

1. **Performance Analysis**:

   - Identify slow operations
   - Find bottlenecks in request flow
   - Analyze latency distribution
   - Compare performance across versions

2. **Error Investigation**:

   - Trace error propagation
   - Identify failure points
   - Correlate errors with infrastructure events
   - Debug complex distributed failures

3. **Dependency Mapping**:
   - Visualize service interactions
   - Understand data flow
   - Identify unused dependencies
   - Plan service decomposition

### Jaeger UI Features

1. **Search Interface**:

   - Filter by service, operation, tags
   - Time range selection
   - Duration and error filtering
   - Custom query building

2. **Trace Timeline**:

   - Span waterfall view
   - Timing information
   - Nested span relationships
   - Critical path highlighting

3. **Service Map**:
   - Visual dependency graph
   - Request flow visualization
   - Service health indicators
   - Performance metrics overlay

## Troubleshooting

### Common Issues

1. **No Traces Appearing**:

   ```bash
   # Check agent connectivity
   kubectl logs -n monitoring deployment/jaeger

   # Verify application instrumentation
   kubectl logs <app-pod> | grep -i jaeger

   # Check sampling configuration
   curl http://jaeger-query:16686/api/sampling?service=<service-name>
   ```

2. **High Latency in UI**:

   ```bash
   # Check storage backend performance
   kubectl top pods -n monitoring

   # Review trace volume
   kubectl logs -n monitoring deployment/jaeger | grep "spans received"

   # Optimize query performance
   # Consider trace archival or sampling adjustment
   ```

3. **Missing Spans**:

   ```bash
   # Verify network connectivity
   kubectl exec -it <app-pod> -- telnet jaeger-agent 6832

   # Check instrumentation coverage
   # Review application logs for span creation

   # Validate sampling configuration
   ```

### Performance Optimization

1. **Storage Optimization**:

   - Use appropriate storage backends
   - Implement trace archival
   - Configure retention policies
   - Monitor storage growth

2. **Query Performance**:

   - Add proper indexes
   - Use efficient time ranges
   - Optimize tag queries
   - Cache frequent searches

3. **Collection Efficiency**:
   - Batch trace submissions
   - Use appropriate buffer sizes
   - Implement backpressure handling
   - Monitor agent performance

## Integration with Other Observability Tools

### Metrics Correlation

```yaml
# Prometheus metrics with trace context
http_requests_total{trace_id="abc123"}
request_duration_seconds{trace_id="abc123"}
```

### Log Correlation

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "level": "ERROR",
  "message": "Database connection failed",
  "trace_id": "abc123",
  "span_id": "def456"
}
```

### Alerting Integration

```yaml
# Alert on high error rates in traces
groups:
  - name: tracing.rules
    rules:
      - alert: HighTraceErrorRate
        expr: rate(jaeger_spans_total{result="error"}[5m]) > 0.1
        labels:
          severity: warning
        annotations:
          summary: "High error rate in traces"
```

## Security Considerations

1. **Data Protection**:

   - Avoid sensitive data in spans
   - Implement data sanitization
   - Use secure transport (TLS)
   - Configure access controls

2. **Network Security**:

   - Restrict agent access
   - Use network policies
   - Implement firewall rules
   - Monitor trace data flow

3. **Authentication**:
   - Secure Jaeger UI access
   - Implement RBAC
   - Use identity providers
   - Audit access logs

## Maintenance

### Regular Tasks

- Clean up old traces
- Update Jaeger versions
- Review sampling strategies
- Monitor storage usage

### Health Checks

```bash
# Check Jaeger health
curl http://jaeger-query:16686/api/services

# Verify trace ingestion
curl http://jaeger-agent:14271/metrics

# Monitor storage health
kubectl exec -it jaeger-pod -- jaeger-admin check-health
```

## Advanced Features

### Custom Collectors

- Implement custom trace processors
- Add business-specific enrichment
- Integrate with external systems
- Implement trace routing

### OpenTelemetry Integration

- Migrate from OpenTracing
- Use OTEL collectors
- Implement OTEL instrumentation
- Configure OTEL pipelines

## Resources

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTracing Specification](https://opentracing.io/)
- [OpenTelemetry Documentation](https://opentelemetry.io/)
- [Distributed Tracing Best Practices](https://peter.bourgon.org/blog/2017/02/21/metrics-tracing-and-logging.html)

## Contributing

When adding new tracing components:

1. Update instrumentation examples
2. Add service-specific configurations
3. Document new trace patterns
4. Test trace collection and visualization
5. Update troubleshooting guides
