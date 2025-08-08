# 🔄 Migration Guide: Centralized Tracing Module

This guide helps you migrate your existing services to use the centralized tracing module located in `/tracing`.

## 📋 Migration Steps

### 1. **Update Import Statements**

#### Before (Individual service configs):

```javascript
// services/api-gateway/src/app.js
const initTracer = require("./config/jaeger");
const { createTracingMiddleware } = require("./middleware/tracing");
```

#### After (Centralized module):

```javascript
// services/api-gateway/src/app.js
const {
  initJaegerTracer,
  createTracingMiddleware,
} = require("../../../tracing");
```

### 2. **Update Tracer Initialization**

#### Before:

```javascript
const tracer = initTracer("api-gateway");
```

#### After:

```javascript
const tracer = initJaegerTracer("api-gateway");
```

### 3. **Update Helper Function Imports**

#### Before:

```javascript
const { traceDbOperation, traceHttpCall } = require("./middleware/tracing");
```

#### After:

```javascript
const {
  traceDbOperation,
  traceHttpCall,
  traceKafkaOperation,
} = require("../../../tracing");
```

## 🔧 Service-Specific Updates

### API Gateway Migration

```javascript
// services/api-gateway/src/app.js

// OLD IMPORTS - Remove these
// const initTracer = require('./config/jaeger');
// const { createTracingMiddleware, traceHttpCall } = require('./middleware/tracing');

// NEW IMPORTS - Add this
const {
  initJaegerTracer,
  createTracingMiddleware,
  traceHttpCall,
} = require("../../../tracing");

// Update tracer initialization
const tracer = initJaegerTracer("api-gateway");
```

### Order Service Migration

```javascript
// services/order-service/src/app.js

// OLD IMPORTS - Remove these
// const { initJaegerTracer } = require('./config/jaeger');
// const { createTracingMiddleware } = require('./middleware/tracing');

// NEW IMPORTS - Add this
const {
  initJaegerTracer,
  createTracingMiddleware,
  traceDbOperation,
  traceKafkaOperation,
} = require("../../../tracing");

// Tracer initialization remains the same
const tracer = initJaegerTracer("order-service");
```

### Auth Service Migration (When Available)

```javascript
// services/auth-service/src/app.js

// NEW IMPORTS
const {
  initJaegerTracer,
  createTracingMiddleware,
  traceDbOperation,
} = require("../../../tracing");

// Initialize tracer
const tracer = initJaegerTracer("auth-service");

// Add tracing middleware
app.use(createTracingMiddleware(tracer));
```

## 📁 File Cleanup

After migration, you can remove these service-specific files:

### API Gateway Cleanup

```bash
# Remove old tracing files
rm services/api-gateway/src/config/jaeger.js
rm services/api-gateway/src/middleware/tracing.js
```

### Order Service Cleanup

```bash
# Remove old tracing files
rm services/order-service/src/config/jaeger.js
rm services/order-service/src/middleware/tracing.js
```

## 🚀 Deployment Updates

### Update Kubernetes Deployments

Use the centralized Kubernetes configuration:

```bash
# Deploy using centralized config
kubectl apply -f tracing/k8s/jaeger-enabled-deployments.yaml
```

### Update Docker Build Context

Ensure your Docker builds include the tracing directory:

```dockerfile
# In your service Dockerfile
WORKDIR /app

# Copy the entire project (including tracing module)
COPY . .

# Or specifically copy tracing module
COPY tracing/ ./tracing/
COPY services/your-service/ ./services/your-service/
```

## 🧪 Testing Migration

### 1. **Verify Imports Work**

```bash
# In your service directory
node -e "console.log(require('../../tracing'))"
```

### 2. **Test Service Startup**

```bash
# Start your service and check for tracing logs
npm start

# Look for logs like:
# JAEGER INFO: Tracer initialized
```

### 3. **Run Integration Tests**

```bash
# Use the centralized test script
chmod +x tracing/scripts/test-jaeger-tracing.sh
./tracing/scripts/test-jaeger-tracing.sh
```

## ⚠️ Common Migration Issues

### 1. **Import Path Errors**

**Issue**: `Cannot find module '../../../tracing'`

**Solution**: Verify the relative path from your service to the tracing directory:

```bash
# From services/api-gateway/src/app.js
# Path should be: ../../../tracing
#
# Directory structure:
# microservices-platform/
# ├── tracing/           <- Target
# └── services/
#     └── api-gateway/
#         └── src/
#             └── app.js  <- Current file
```

### 2. **Environment Variable Conflicts**

**Issue**: Service-specific environment variables not working

**Solution**: Update your environment variables to use the centralized format:

```bash
# Old service-specific variables
JAEGER_ENDPOINT=http://...

# New centralized variables
JAEGER_COLLECTOR_URL=http://...
JAEGER_AGENT_HOST=jaeger-agent.observability.svc.cluster.local
JAEGER_AGENT_PORT=6832
```

### 3. **Package.json Dependencies**

**Issue**: Missing tracing dependencies

**Solution**: Ensure jaeger-client and opentracing are in each service's package.json:

```json
{
  "dependencies": {
    "jaeger-client": "^3.19.0",
    "opentracing": "^0.14.7"
  }
}
```

## 📊 Migration Verification Checklist

- [ ] Service imports from centralized tracing module
- [ ] Old service-specific tracing files removed
- [ ] Service starts without errors
- [ ] Traces appear in Jaeger UI
- [ ] Service-to-service tracing works
- [ ] Error traces are captured
- [ ] Performance impact is acceptable

## 🎯 Benefits After Migration

### ✅ **Consistency**

- Unified tracing configuration across all services
- Consistent span naming and tagging
- Standardized error handling

### ✅ **Maintainability**

- Single source of truth for tracing logic
- Easier updates and bug fixes
- Centralized documentation

### ✅ **Scalability**

- Easy to add tracing to new services
- Shared helper functions
- Reusable components

### ✅ **Development Experience**

- Simplified service setup
- Better debugging capabilities
- Comprehensive testing tools

## 🚀 Next Steps After Migration

1. **Deploy Updated Services**:

   ```bash
   ./tracing/scripts/deploy-jaeger-enabled.sh
   ```

2. **Generate Test Traces**:

   ```bash
   ./tracing/scripts/test-jaeger-tracing.sh
   ```

3. **Monitor in Jaeger UI**:

   - Visit: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
   - Search for traces from your migrated services
   - Verify end-to-end tracing works

4. **Review Performance**:
   - Monitor service startup times
   - Check memory usage impact
   - Adjust sampling rates if needed

---

_Migration complete! Your services now use the centralized tracing module for better maintainability and consistency._
