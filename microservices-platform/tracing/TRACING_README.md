# 🔍 Jaeger Distributed Tracing Module

This directory contains all the centralized components for implementing Jaeger distributed tracing across your microservices platform.

## 📁 Directory Structure

```
tracing/
├── index.js                          # Main entry point for tracing module
├── configs/
│   └── jaeger-config.js              # Jaeger tracer configuration
├── middleware/
│   └── tracing-middleware.js         # Express middleware for tracing
├── k8s/
│   └── jaeger-enabled-deployments.yaml # Kubernetes deployments with tracing
├── scripts/
│   ├── deploy-jaeger-enabled.sh      # Deployment automation script
│   └── test-jaeger-tracing.sh        # Testing and demo script
└── docs/
    ├── JAEGER_INTEGRATION_GUIDE.md   # Comprehensive integration guide
    └── JAEGER_IMPLEMENTATION_COMPLETE.md # Implementation status doc
```

## 🚀 Quick Start

### 1. Install in Your Service

```bash
# From your service directory (e.g., services/api-gateway/)
npm install jaeger-client opentracing
```

### 2. Import and Use

```javascript
// In your service's app.js
const { initJaegerTracer, createTracingMiddleware } = require("../../tracing");

// Initialize tracer
const tracer = initJaegerTracer("your-service-name");

// Add tracing middleware
app.use(createTracingMiddleware(tracer));
```

### 3. Use Helper Functions

```javascript
const {
  traceDbOperation,
  traceHttpCall,
  traceKafkaOperation,
} = require("../../tracing");

// Trace database operations
const dbTrace = traceDbOperation(tracer, parentSpan, "findOne", "users", {
  id: userId,
});
try {
  const result = await User.findById(userId);
  dbTrace.finish(null, result);
} catch (error) {
  dbTrace.finish(error);
}

// Trace HTTP calls
const httpTrace = traceHttpCall(
  tracer,
  parentSpan,
  "GET",
  "http://user-service:3001/users/123"
);
try {
  const response = await fetch(url, { headers: httpTrace.headers });
  httpTrace.finish(null, response);
} catch (error) {
  httpTrace.finish(error);
}

// Trace Kafka operations
const kafkaTrace = traceKafkaOperation(
  tracer,
  parentSpan,
  "publish",
  "user-events",
  message
);
try {
  await producer.send(message);
  kafkaTrace.finish(null, { partition: 0, offset: 123 });
} catch (error) {
  kafkaTrace.finish(error);
}
```

## 🔧 Configuration

### Environment Variables

Set these environment variables in your Kubernetes deployments:

```bash
JAEGER_AGENT_HOST=jaeger-agent.observability.svc.cluster.local
JAEGER_AGENT_PORT=6832
JAEGER_COLLECTOR_URL=http://jaeger-collector.observability.svc.cluster.local:14268/api/traces
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1
SERVICE_NAME=your-service-name
SERVICE_VERSION=1.0.0
NODE_ENV=production
```

### Kubernetes ConfigMap

Use the ConfigMap defined in `k8s/jaeger-enabled-deployments.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jaeger-config
  namespace: microservices
data:
  JAEGER_AGENT_HOST: "jaeger-agent.observability.svc.cluster.local"
  JAEGER_AGENT_PORT: "6832"
  # ... other config
```

## 📊 Current External URLs

- **Jaeger UI**: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
- **Prometheus**: http://ab58fe70bf87f485f9a173654802a55b-e11584559552f59d1.elb.us-west-2.amazonaws.com:9090

## 🛠️ Scripts Usage

### Deploy with Tracing

```bash
# Make executable and run
chmod +x tracing/scripts/deploy-jaeger-enabled.sh
./tracing/scripts/deploy-jaeger-enabled.sh
```

### Test Tracing

```bash
# Generate test traces
chmod +x tracing/scripts/test-jaeger-tracing.sh
./tracing/scripts/test-jaeger-tracing.sh
```

## 📚 Documentation

- **Integration Guide**: `docs/JAEGER_INTEGRATION_GUIDE.md` - Comprehensive setup guide
- **Implementation Status**: `docs/JAEGER_IMPLEMENTATION_COMPLETE.md` - Current status and features

## 🎯 Features

### ✅ Current Features

- **Automatic Request Tracing**: HTTP requests/responses
- **Service-to-Service Tracing**: Trace context propagation
- **Database Operation Tracing**: MongoDB, PostgreSQL operations
- **Message Queue Tracing**: Kafka producer/consumer
- **Error Correlation**: Error tracking across services
- **Performance Monitoring**: Request timing and bottlenecks

### 🔮 Planned Features

- **Business Context Tracing**: Custom business metrics
- **Advanced Sampling**: Intelligent sampling strategies
- **Alerting Integration**: Prometheus alerts for trace metrics
- **Custom Dashboards**: Grafana dashboards for trace analytics

## 📈 Best Practices

1. **Service Naming**: Use consistent service names across all components
2. **Sampling**: Adjust sampling rates for production environments
3. **Error Handling**: Always handle tracing errors gracefully
4. **Performance**: Monitor tracing overhead in production
5. **Security**: Don't trace sensitive data (passwords, tokens, etc.)

## 🐛 Troubleshooting

### Common Issues

1. **No traces appearing**: Check Jaeger agent connectivity
2. **High memory usage**: Reduce sampling rate
3. **Missing correlations**: Verify trace header forwarding
4. **Performance impact**: Adjust sampling and span creation

### Debug Commands

```bash
# Check Jaeger connectivity
kubectl logs deployment/your-service -n microservices | grep JAEGER

# Verify environment variables
kubectl exec deployment/your-service -n microservices -- env | grep JAEGER

# Check Jaeger collector logs
kubectl logs deployment/jaeger -n observability
```

---

For detailed implementation instructions, see the documentation in the `docs/` directory.
