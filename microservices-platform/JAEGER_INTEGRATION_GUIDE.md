# 🔍 Jaeger Distributed Tracing Integration Guide

## 📚 **What is Jaeger and How Does it Work?**

### **🎯 Core Concepts**

#### **Distributed Tracing Fundamentals**

- **Trace**: Complete journey of a request across multiple services
- **Span**: Individual operation within a trace (e.g., HTTP request, database query)
- **Context Propagation**: Passing trace information between services
- **Sampling**: Deciding which requests to trace (to manage overhead)

#### **Jaeger Architecture**

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Microservice│    │ Microservice│    │ Microservice│
│     A       │───▶│     B       │───▶│     C       │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────┐
│               Jaeger Agent                          │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────┐
│               Jaeger Collector                      │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────┐
│               Jaeger Storage                        │
│            (Elasticsearch/Cassandra)               │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────┐
│               Jaeger UI                             │
│     http://jaeger-url:16686                        │
└─────────────────────────────────────────────────────┘
```

---

## 🛠️ **Integrating Your Microservices with Jaeger**

### **Current Jaeger Setup**

- **Jaeger UI**: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
- **Jaeger Collector**: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:14268

### **🔧 Node.js Microservices Integration**

#### **1. Install Required Packages**

```bash
# For each microservice directory
npm install jaeger-client opentracing
```

#### **2. Create Jaeger Configuration Module**

```javascript
// src/config/jaeger.js
const initJaegerTracer = require("jaeger-client").initTracer;

function initTracer(serviceName) {
  const config = {
    serviceName: serviceName,
    sampler: {
      type: "const",
      param: 1, // Sample 100% of traces (reduce in production)
    },
    reporter: {
      // Send traces to your Jaeger collector
      endpoint:
        "http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:14268/api/traces",
      logSpans: true,
    },
  };

  const options = {
    tags: {
      "microservice.version": process.env.SERVICE_VERSION || "1.0.0",
      "microservice.environment": process.env.NODE_ENV || "development",
    },
    logger: {
      info: function logInfo(msg) {
        console.log("TRACER INFO:", msg);
      },
      error: function logError(msg) {
        console.error("TRACER ERROR:", msg);
      },
    },
  };

  return initJaegerTracer(config, options);
}

module.exports = initTracer;
```

#### **3. Integrate Tracing in Your Services**

##### **API Gateway Integration**

```javascript
// api-gateway/src/app.js
const express = require("express");
const opentracing = require("opentracing");
const initTracer = require("./config/jaeger");

const app = express();
const tracer = initTracer("api-gateway");

// Set global tracer
opentracing.initGlobalTracer(tracer);

// Tracing middleware
function tracingMiddleware(req, res, next) {
  const wireCtx = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: wireCtx,
  });

  // Add request details to span
  span.setTag(opentracing.Tags.HTTP_METHOD, req.method);
  span.setTag(opentracing.Tags.HTTP_URL, req.url);
  span.setTag(
    opentracing.Tags.SPAN_KIND,
    opentracing.Tags.SPAN_KIND_RPC_SERVER
  );

  // Store span in request object
  req.span = span;

  // Inject trace context for downstream services
  req.traceHeaders = {};
  tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, req.traceHeaders);

  res.on("finish", () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    if (res.statusCode >= 400) {
      span.setTag(opentracing.Tags.ERROR, true);
    }
    span.finish();
  });

  next();
}

app.use(tracingMiddleware);

// Example route with manual span creation
app.get("/api/users/:id", async (req, res) => {
  const span = req.span;

  try {
    // Create child span for external service call
    const userSpan = tracer.startSpan("fetch-user-data", {
      childOf: span,
    });

    userSpan.setTag("user.id", req.params.id);

    // Call user service with trace headers
    const userResponse = await fetch(
      "http://user-service:3001/users/" + req.params.id,
      {
        headers: {
          ...req.traceHeaders,
          "Content-Type": "application/json",
        },
      }
    );

    userSpan.setTag("http.status_code", userResponse.status);
    userSpan.finish();

    const userData = await userResponse.json();
    res.json(userData);
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({ event: "error", message: error.message });
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 API Gateway listening on port ${PORT}`);
  console.log(`📊 Tracing enabled - sending to Jaeger`);
});
```

##### **User Service Integration**

```javascript
// user-service/src/app.js
const express = require("express");
const opentracing = require("opentracing");
const initTracer = require("./config/jaeger");

const app = express();
const tracer = initTracer("user-service");
opentracing.initGlobalTracer(tracer);

// Tracing middleware for incoming requests
function tracingMiddleware(req, res, next) {
  const wireCtx = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: wireCtx,
  });

  span.setTag(opentracing.Tags.HTTP_METHOD, req.method);
  span.setTag(opentracing.Tags.HTTP_URL, req.url);
  span.setTag(
    opentracing.Tags.SPAN_KIND,
    opentracing.Tags.SPAN_KIND_RPC_SERVER
  );

  req.span = span;
  req.traceHeaders = {};
  tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, req.traceHeaders);

  res.on("finish", () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    if (res.statusCode >= 400) {
      span.setTag(opentracing.Tags.ERROR, true);
    }
    span.finish();
  });

  next();
}

app.use(tracingMiddleware);

// Database query with tracing
async function getUserFromDatabase(userId, parentSpan) {
  const dbSpan = tracer.startSpan("database-query", {
    childOf: parentSpan,
  });

  dbSpan.setTag("db.type", "postgresql");
  dbSpan.setTag("db.statement", "SELECT * FROM users WHERE id = $1");
  dbSpan.setTag("user.id", userId);

  try {
    // Simulate database query
    await new Promise((resolve) => setTimeout(resolve, Math.random() * 100));

    const user = {
      id: userId,
      name: `User ${userId}`,
      email: `user${userId}@example.com`,
      timestamp: new Date().toISOString(),
    };

    dbSpan.setTag("db.rows_affected", 1);
    dbSpan.finish();
    return user;
  } catch (error) {
    dbSpan.setTag(opentracing.Tags.ERROR, true);
    dbSpan.log({ event: "error", message: error.message });
    dbSpan.finish();
    throw error;
  }
}

app.get("/users/:id", async (req, res) => {
  const span = req.span;

  try {
    const user = await getUserFromDatabase(req.params.id, span);

    span.setTag("user.found", true);
    span.log({ event: "user_retrieved", userId: user.id });

    res.json({
      success: true,
      user: user,
    });
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({ event: "error", message: error.message });
    res.status(500).json({ error: "Failed to get user" });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`👤 User Service listening on port ${PORT}`);
  console.log(`📊 Tracing enabled - sending to Jaeger`);
});
```

##### **Order Service Integration (Enhanced)**

```javascript
// order-service/src/app.js
const express = require("express");
const opentracing = require("opentracing");
const initTracer = require("./config/jaeger");
const kafkaService = require("./services/kafkaService");

const app = express();
const tracer = initTracer("order-service");
opentracing.initGlobalTracer(tracer);

// Enhanced tracing middleware
function tracingMiddleware(req, res, next) {
  const wireCtx = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
  const span = tracer.startSpan(`${req.method} ${req.path}`, {
    childOf: wireCtx,
  });

  span.setTag(opentracing.Tags.HTTP_METHOD, req.method);
  span.setTag(opentracing.Tags.HTTP_URL, req.url);
  span.setTag(
    opentracing.Tags.SPAN_KIND,
    opentracing.Tags.SPAN_KIND_RPC_SERVER
  );
  span.setTag("service.name", "order-service");

  req.span = span;
  req.traceHeaders = {};
  tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, req.traceHeaders);

  res.on("finish", () => {
    span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
    if (res.statusCode >= 400) {
      span.setTag(opentracing.Tags.ERROR, true);
    }
    span.finish();
  });

  next();
}

app.use(tracingMiddleware);

// Order creation with comprehensive tracing
app.post("/orders", async (req, res) => {
  const span = req.span;
  const { userId, items, totalAmount } = req.body;

  try {
    // 1. Validate order data
    const validationSpan = tracer.startSpan("validate-order", {
      childOf: span,
    });

    validationSpan.setTag("order.userId", userId);
    validationSpan.setTag("order.itemCount", items.length);
    validationSpan.setTag("order.totalAmount", totalAmount);

    if (!userId || !items || items.length === 0) {
      validationSpan.setTag(opentracing.Tags.ERROR, true);
      validationSpan.log({
        event: "validation_failed",
        reason: "missing_required_fields",
      });
      validationSpan.finish();
      return res.status(400).json({ error: "Invalid order data" });
    }
    validationSpan.finish();

    // 2. Create order in database
    const dbSpan = tracer.startSpan("create-order-db", {
      childOf: span,
    });

    dbSpan.setTag("db.type", "postgresql");
    dbSpan.setTag("db.operation", "INSERT");

    // Simulate database insertion
    await new Promise((resolve) => setTimeout(resolve, 50));
    const orderId = `order_${Date.now()}`;

    dbSpan.setTag("order.id", orderId);
    dbSpan.finish();

    // 3. Publish to Kafka with tracing
    const kafkaSpan = tracer.startSpan("publish-order-event", {
      childOf: span,
    });

    kafkaSpan.setTag("messaging.system", "kafka");
    kafkaSpan.setTag("messaging.destination", "order-events");
    kafkaSpan.setTag("messaging.operation", "publish");

    const orderEvent = {
      type: "order-created",
      orderId: orderId,
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      timestamp: new Date().toISOString(),
      // Include trace context in the message
      traceId: span.context().traceId,
      spanId: span.context().spanId,
    };

    try {
      await kafkaService.publishEvent("order-events", orderEvent);
      kafkaSpan.setTag("messaging.success", true);
      kafkaSpan.log({ event: "message_published", orderId: orderId });
    } catch (kafkaError) {
      kafkaSpan.setTag(opentracing.Tags.ERROR, true);
      kafkaSpan.log({ event: "publish_failed", error: kafkaError.message });
      throw kafkaError;
    }
    kafkaSpan.finish();

    // 4. Call inventory service
    const inventorySpan = tracer.startSpan("check-inventory", {
      childOf: span,
    });

    inventorySpan.setTag("http.method", "POST");
    inventorySpan.setTag("http.url", "http://inventory-service:3004/check");

    try {
      const inventoryResponse = await fetch(
        "http://inventory-service:3004/check",
        {
          method: "POST",
          headers: {
            ...req.traceHeaders,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ items }),
        }
      );

      inventorySpan.setTag("http.status_code", inventoryResponse.status);

      if (!inventoryResponse.ok) {
        inventorySpan.setTag(opentracing.Tags.ERROR, true);
        inventorySpan.log({
          event: "inventory_check_failed",
          status: inventoryResponse.status,
        });
      }

      inventorySpan.finish();
    } catch (inventoryError) {
      inventorySpan.setTag(opentracing.Tags.ERROR, true);
      inventorySpan.log({
        event: "inventory_service_unreachable",
        error: inventoryError.message,
      });
      inventorySpan.finish();
      // Continue processing even if inventory check fails
    }

    // Success response
    span.setTag("order.created", true);
    span.setTag("order.id", orderId);
    span.log({ event: "order_created_successfully", orderId: orderId });

    res.status(201).json({
      success: true,
      orderId: orderId,
      message: "Order created successfully",
    });
  } catch (error) {
    span.setTag(opentracing.Tags.ERROR, true);
    span.log({ event: "order_creation_failed", error: error.message });
    res.status(500).json({
      error: "Failed to create order",
      details: error.message,
    });
  }
});

const PORT = process.env.PORT || 3003;
app.listen(PORT, () => {
  console.log(`🛒 Order Service listening on port ${PORT}`);
  console.log(`📊 Tracing enabled - sending to Jaeger`);
});
```

### **🐳 Update Dockerfiles with Tracing**

#### **Enhanced Dockerfile for Services**

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies including tracing libraries
RUN npm install

# Copy source code
COPY src/ ./src/

# Environment variables for tracing
ENV NODE_ENV=production
ENV SERVICE_VERSION=1.0.0
ENV JAEGER_SERVICE_NAME=order-service
ENV JAEGER_AGENT_HOST=jaeger-agent
ENV JAEGER_AGENT_PORT=6832

EXPOSE 3003

CMD ["node", "src/app.js"]
```

### **☸️ Update Kubernetes Deployments**

#### **Add Environment Variables for Tracing**

```yaml
# kubernetes/order-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
      annotations:
        # Enable automatic sidecar injection if using service mesh
        sidecar.istio.io/inject: "true"
    spec:
      containers:
        - name: order-service
          image: your-ecr-repo/order-service:latest
          ports:
            - containerPort: 3003
          env:
            - name: NODE_ENV
              value: "production"
            - name: SERVICE_VERSION
              value: "1.0.0"
            - name: JAEGER_SERVICE_NAME
              value: "order-service"
            - name: JAEGER_ENDPOINT
              value: "http://jaeger.monitoring.svc.cluster.local:14268/api/traces"
            - name: JAEGER_SAMPLER_TYPE
              value: "const"
            - name: JAEGER_SAMPLER_PARAM
              value: "1"
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

---

## 🔍 **Testing Your Tracing Integration**

### **1. Test Trace Generation**

```bash
# Make a request to your API Gateway
curl -X POST http://your-api-gateway/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "items": [
      {"productId": "prod1", "quantity": 2, "price": 25.99},
      {"productId": "prod2", "quantity": 1, "price": 15.50}
    ],
    "totalAmount": 67.48
  }'
```

### **2. View Traces in Jaeger UI**

1. Open: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
2. Select service: `api-gateway` or `order-service`
3. Click "Find Traces"
4. Explore the trace timeline and service map

### **3. What You'll See in Jaeger**

- **Service Map**: Visual representation of service dependencies
- **Trace Timeline**: Chronological view of spans
- **Span Details**: Tags, logs, and timing information
- **Error Tracking**: Failed spans highlighted in red

---

## 📊 **Advanced Tracing Patterns**

### **Custom Span Tags for Business Logic**

```javascript
// Add business context to spans
span.setTag("user.tier", "premium");
span.setTag("order.type", "express");
span.setTag("payment.method", "credit_card");
span.setTag("shipping.method", "overnight");

// Log important events
span.log({
  event: "payment_processed",
  amount: 67.48,
  currency: "USD",
  transaction_id: "txn_123456",
});
```

### **Error Handling and Debugging**

```javascript
try {
  await processPayment(orderData);
} catch (error) {
  span.setTag(opentracing.Tags.ERROR, true);
  span.setTag("error.type", error.constructor.name);
  span.log({
    event: "error",
    "error.object": error,
    "error.kind": "payment_failure",
    message: error.message,
    stack: error.stack,
  });
  throw error;
}
```

### **Sampling Strategies**

```javascript
// Production sampling configuration
const config = {
  serviceName: serviceName,
  sampler: {
    type: "probabilistic",
    param: 0.1, // Sample 10% of traces in production
  },
  // Or use adaptive sampling
  sampler: {
    type: "adaptive",
    maxTracesPerSecond: 100,
  },
};
```

---

## 🎯 **Best Practices for Microservices Tracing**

### **1. Consistent Naming**

- Use consistent span operation names across services
- Include HTTP method and endpoint: `GET /api/users/:id`
- Use descriptive names: `validate-payment`, `update-inventory`

### **2. Meaningful Tags**

- Add business context: `user.id`, `order.type`, `payment.method`
- Include technical details: `db.statement`, `http.status_code`
- Use standard OpenTracing tags when possible

### **3. Proper Error Handling**

- Always mark error spans with `error: true`
- Include error details in span logs
- Don't let tracing failures break your application

### **4. Performance Considerations**

- Use appropriate sampling rates for production
- Avoid creating too many spans for simple operations
- Be mindful of the overhead of tracing

---

_This integration will provide complete visibility into your microservices interactions and help you debug performance issues across your distributed system!_
