# 🚀 Quick Integration Steps for Your Microservices

## 📦 **Step 1: Install Dependencies**

For each microservice, run:

```bash
cd your-service-directory
npm install jaeger-client opentracing
```

## 🔧 **Step 2: Add Tracing Files**

Copy these files to each microservice:

- `tracing/jaeger-config.js` → `src/config/jaeger.js`
- `tracing/tracing-middleware.js` → `src/middleware/tracing.js`

## 📝 **Step 3: Update Your Main App Files**

### **API Gateway (src/app.js)**

```javascript
const express = require("express");
const opentracing = require("opentracing");
const initTracer = require("./config/jaeger");
const {
  createTracingMiddleware,
  traceHttpCall,
} = require("./middleware/tracing");

const app = express();

// Initialize Jaeger tracer
const tracer = initTracer("api-gateway");
opentracing.initGlobalTracer(tracer);

// Add tracing middleware
app.use(createTracingMiddleware(tracer, "api-gateway"));

// Example traced route
app.get("/api/users/:id", async (req, res) => {
  const httpSpan = traceHttpCall(
    req.span,
    "GET",
    `http://user-service:3001/users/${req.params.id}`,
    req.traceHeaders
  );

  try {
    const response = await fetch(
      `http://user-service:3001/users/${req.params.id}`,
      {
        headers: req.traceHeaders,
      }
    );

    httpSpan.setTag("http.status_code", response.status);
    httpSpan.finish();

    const data = await response.json();
    res.json(data);
  } catch (error) {
    httpSpan.setTag("error", true);
    httpSpan.log({ event: "error", message: error.message });
    httpSpan.finish();
    res.status(500).json({ error: "Service unavailable" });
  }
});

app.listen(3000, () => {
  console.log("🎯 API Gateway with Jaeger tracing started on port 3000");
});
```

### **Order Service (src/app.js)**

```javascript
const express = require("express");
const opentracing = require("opentracing");
const initTracer = require("./config/jaeger");
const {
  createTracingMiddleware,
  traceDatabase,
  traceKafkaOperation,
} = require("./middleware/tracing");
const kafkaService = require("./services/kafkaService");

const app = express();

// Initialize Jaeger tracer
const tracer = initTracer("order-service");
opentracing.initGlobalTracer(tracer);

// Add tracing middleware
app.use(express.json());
app.use(createTracingMiddleware(tracer, "order-service"));

app.post("/orders", async (req, res) => {
  const { userId, items, totalAmount } = req.body;

  try {
    // Trace database operation
    const dbSpan = traceDatabase(
      req.span,
      "insert",
      "INSERT INTO orders (...) VALUES (...)",
      { userId, totalAmount }
    );

    // Simulate database call
    await new Promise((resolve) => setTimeout(resolve, 50));
    const orderId = `order_${Date.now()}`;

    dbSpan.setTag("db.rows_affected", 1);
    dbSpan.setTag("order.id", orderId);
    dbSpan.finish();

    // Trace Kafka publish
    const kafkaSpan = traceKafkaOperation(req.span, "publish", "order-events");

    const orderEvent = {
      type: "order-created",
      orderId,
      userId,
      items,
      totalAmount,
      timestamp: new Date().toISOString(),
    };

    await kafkaService.publishEvent("order-events", orderEvent);
    kafkaSpan.setTag("messaging.success", true);
    kafkaSpan.finish();

    req.span.setTag("order.created", true);
    req.span.setTag("order.id", orderId);

    res.status(201).json({
      success: true,
      orderId,
      message: "Order created successfully",
    });
  } catch (error) {
    req.span.setTag("error", true);
    req.span.log({ event: "error", message: error.message });
    res.status(500).json({ error: "Failed to create order" });
  }
});

app.listen(3003, () => {
  console.log("🛒 Order Service with Jaeger tracing started on port 3003");
});
```

## 🐳 **Step 4: Update Package.json**

Add tracing dependencies to each service:

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "jaeger-client": "^3.19.0",
    "opentracing": "^0.14.7"
  }
}
```

## ☸️ **Step 5: Update Kubernetes Deployments**

Add environment variables to your deployment YAML files:

```yaml
env:
  - name: JAEGER_ENDPOINT
    value: "http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:14268/api/traces"
  - name: JAEGER_SAMPLER_TYPE
    value: "const"
  - name: JAEGER_SAMPLER_PARAM
    value: "1"
  - name: SERVICE_VERSION
    value: "1.0.0"
  - name: KUBERNETES_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

## 🚀 **Step 6: Deploy and Test**

1. **Rebuild your Docker images** with the new tracing code
2. **Deploy to Kubernetes** with updated environment variables
3. **Make test requests** to your services
4. **View traces** in Jaeger UI: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686

## 🔍 **Testing Your Integration**

### Test API Call

```bash
curl -X POST http://your-api-gateway/api/orders \
  -H "Content-Type: application/json" \
  -H "User-ID: user123" \
  -d '{
    "userId": "user123",
    "items": [{"productId": "prod1", "quantity": 2}],
    "totalAmount": 50.00
  }'
```

### Check Jaeger UI

1. Open Jaeger: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
2. Select Service: `api-gateway`, `order-service`, etc.
3. Click "Find Traces"
4. Explore the trace timeline showing the request flow across services

## 🎯 **What You'll See in Jaeger**

- **Service Map**: Visual graph of service dependencies
- **Trace Timeline**: Chronological spans showing request flow
- **Span Details**: HTTP status codes, database queries, error logs
- **Performance Metrics**: Response times, bottlenecks, errors

Your microservices will now have complete distributed tracing! 🎉
