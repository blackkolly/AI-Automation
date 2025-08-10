# 📚 API Reference

## Feature Flags Service API

### Base URL
```
http://feature-flags-service:3000
```

---

## Endpoints

### 🏥 Health Check

**GET** `/health`

Returns the current health status of the feature flags service.

**Response:**
```json
{
  "service": "feature-flags-service",
  "status": "healthy",
  "uptime": 3600000,
  "flagsLoaded": 6,
  "environment": "production",
  "timestamp": "2025-08-09T17:00:00Z"
}
```

---

### 🏁 Get All Flags

**GET** `/flags`

Returns all feature flags with their current configuration.

**Response:**
```json
{
  "service": "feature-flags-service",
  "flags": {
    "analytics": {
      "enabled": true,
      "rollout": 100,
      "description": "Advanced analytics and reporting",
      "environments": ["development", "staging", "production"],
      "constraints": {
        "userPercentage": 100,
        "regions": ["us", "eu", "asia"],
        "minVersion": "1.0.0"
      }
    }
  },
  "globalSettings": {
    "environment": "production",
    "version": "1.4.0",
    "region": "us"
  },
  "timestamp": "2025-08-09T17:00:00Z"
}
```

---

### 🎯 Evaluate Single Flag

**GET** `/flag/{flagName}`

Evaluates a specific feature flag for the given context.

**Parameters:**
- `flagName` (path) - Name of the feature flag
- `userId` (query) - User identifier for targeting
- `environment` (query) - Environment context
- `region` (query) - Geographic region
- `version` (query) - Application version

**Example:**
```bash
curl "http://feature-flags-service:3000/flag/analytics?userId=user123&environment=production&region=us&version=1.2.0"
```

**Response:**
```json
{
  "service": "feature-flags-service",
  "flagName": "analytics",
  "evaluation": {
    "enabled": true,
    "reason": "All constraints satisfied",
    "rollout": 100
  },
  "context": {
    "userId": "user123",
    "environment": "production",
    "region": "us",
    "version": "1.2.0"
  },
  "timestamp": "2025-08-09T17:00:00Z"
}
```

---

### 📊 Bulk Evaluation

**POST** `/evaluate`

Evaluates multiple feature flags in a single request.

**Request Body:**
```json
{
  "context": {
    "userId": "user123",
    "environment": "production",
    "region": "us",
    "version": "1.2.0"
  },
  "flags": ["analytics", "caching", "newUserInterface"]
}
```

**Response:**
```json
{
  "service": "feature-flags-service",
  "evaluations": {
    "analytics": {
      "enabled": true,
      "reason": "All constraints satisfied",
      "rollout": 100
    },
    "caching": {
      "enabled": true,
      "reason": "All constraints satisfied", 
      "rollout": 80
    },
    "newUserInterface": {
      "enabled": false,
      "reason": "Environment development not allowed"
    }
  },
  "context": {
    "userId": "user123",
    "environment": "production",
    "region": "us",
    "version": "1.2.0"
  },
  "timestamp": "2025-08-09T17:00:00Z"
}
```

---

### 🔄 Reload Configuration

**POST** `/reload`

Reloads the feature flags configuration from the ConfigMap.

**Response:**
```json
{
  "service": "feature-flags-service",
  "message": "Feature flags reloaded successfully",
  "flagsCount": 6,
  "timestamp": "2025-08-09T17:00:00Z"
}
```

---

## Rollback Webhook API

### Base URL
```
http://rollback-webhook:8080
```

---

### 🔄 Trigger Rollback

**POST** `/rollback`

Triggers an automated rollback for a specific service.

**Request Body:**
```json
{
  "service": "api-gateway",
  "deploymentType": "canary",
  "reason": "High error rate detected"
}
```

**Response:**
```json
{
  "success": true,
  "output": "Rollback completed successfully for api-gateway"
}
```

---

## CLI Commands Reference

### Main Orchestration Script

```bash
./sophisticated-release-patterns.sh <command> [options]
```

**Commands:**
- `setup` - Setup infrastructure and scripts
- `deploy <service> <tag> [strategy]` - Deploy with specified strategy
- `blue-green <service> <tag>` - Blue-green deployment
- `canary <service> <tag>` - Canary deployment
- `feature-flag <service> <tag>` - Feature flag deployment
- `full <service> <tag>` - Full deployment with all strategies
- `ab-test <service> <tag-a> <tag-b> [duration]` - A/B testing
- `status` - Show status dashboard
- `cleanup` - Clean up all resources

### Blue-Green Deployment

```bash
./blue-green/blue-green-deploy.sh <command> [options]
```

**Commands:**
- `deploy <service> <image_tag>` - Deploy to inactive environment
- `switch <service> <version>` - Switch traffic between environments
- `status <service>` - Get deployment status
- `rollback <service>` - Rollback to previous version
- `cleanup <service>` - Clean up resources

### Canary Deployment

```bash
./canary/canary-deploy.sh <command> [options]
```

**Commands:**
- `deploy <service> <image_tag>` - Start canary deployment
- `traffic <service> <percentage>` - Set traffic percentage
- `promote <service>` - Promote canary to stable
- `rollback <service>` - Rollback canary deployment
- `status <service>` - Get canary status

### Feature Flags Management

```bash
./feature-flags/feature-flags-manager.sh <command> [options]
```

**Commands:**
- `deploy` - Deploy feature flags service
- `list` - List all feature flags
- `status <flag-name> [context]` - Get flag status
- `update <flag-name> <enabled> [rollout]` - Update flag
- `create <flag-name> [description] [enabled] [rollout]` - Create flag
- `delete <flag-name>` - Delete flag
- `rollout <flag-name> <percentage> [step] [interval]` - Gradual rollout
- `rollback <flag-name>` - Rollback flag
- `emergency` - Emergency shutdown all flags
- `ab-test <flag-name> <a-percent> <b-percent> [duration]` - A/B test

### Rollback Automation

```bash
./rollback-automation.sh <command> [options]
```

**Commands:**
- `monitor <service> <type> [duration]` - Monitor and auto-rollback
- `monitor-all [duration]` - Monitor all services
- `rollback-blue-green <service> [reason]` - Rollback blue-green
- `rollback-canary <service> [reason]` - Rollback canary
- `rollback-regular <service> [reason]` - Rollback regular deployment
- `rollback-flag <flag-name> [reason]` - Rollback feature flag
- `rollback-system [reason]` - System-wide rollback
- `health-check <service>` - Check service health
- `setup-webhook [port]` - Setup rollback webhook

---

## Error Codes

### Feature Flags Service

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid JSON or parameters |
| 404 | Not Found - Flag or endpoint not found |
| 500 | Internal Server Error - Configuration error |

### Rollback Webhook

| Code | Description |
|------|-------------|
| 200 | Rollback successful |
| 400 | Bad Request - Invalid rollback request |
| 404 | Not Found - Invalid endpoint |
| 500 | Internal Server Error - Rollback failed |

---

## Rate Limiting

The feature flags service implements basic rate limiting:
- **100 requests per minute** per client IP
- **Burst capacity**: 20 requests
- **Headers**: `X-RateLimit-Remaining`, `X-RateLimit-Reset`

---

## Authentication

Currently, the APIs use basic authentication:
- **Feature Flags**: Cluster-internal access only
- **Rollback Webhook**: IP allowlist recommended
- **Future**: OAuth2/JWT integration planned

---

## Monitoring Endpoints

### Prometheus Metrics

**GET** `/metrics` (Port 9090)

Provides Prometheus-compatible metrics:

```
# HELP feature_flags_requests_total Total requests
# TYPE feature_flags_requests_total counter
feature_flags_requests_total{service="feature-flags-service",environment="production"} 1234

# HELP feature_flags_uptime_seconds Uptime
# TYPE feature_flags_uptime_seconds gauge
feature_flags_uptime_seconds{service="feature-flags-service",environment="production"} 3600

# HELP feature_flags_count Total feature flags
# TYPE feature_flags_count gauge
feature_flags_count{service="feature-flags-service",environment="production"} 6
```

---

## SDKs and Client Libraries

### JavaScript/Node.js

```javascript
const FeatureFlagsClient = require('./feature-flags-client');

const client = new FeatureFlagsClient('http://feature-flags-service:3000');

// Evaluate single flag
const isEnabled = await client.isEnabled('analytics', {
  userId: 'user123',
  environment: 'production'
});

// Bulk evaluation
const flags = await client.evaluateFlags(['analytics', 'caching'], {
  userId: 'user123',
  environment: 'production'
});
```

### Python

```python
from feature_flags_client import FeatureFlagsClient

client = FeatureFlagsClient('http://feature-flags-service:3000')

# Evaluate single flag
is_enabled = client.is_enabled('analytics', 
    user_id='user123', 
    environment='production'
)

# Bulk evaluation  
flags = client.evaluate_flags(['analytics', 'caching'],
    user_id='user123',
    environment='production'
)
```

---

## WebSocket Support

For real-time flag updates:

```javascript
const ws = new WebSocket('ws://feature-flags-service:3000/ws');

ws.on('message', (data) => {
  const update = JSON.parse(data);
  console.log('Flag updated:', update.flagName, update.newValue);
});

// Subscribe to specific flags
ws.send(JSON.stringify({
  action: 'subscribe',
  flags: ['analytics', 'caching']
}));
```

---

## Examples

### Complete Deployment Flow

```bash
# 1. Setup infrastructure
./sophisticated-release-patterns.sh setup

# 2. Create feature flag for new version
./feature-flags/feature-flags-manager.sh create "api_v2" "API Version 2.0" false 0

# 3. Deploy with canary strategy
./sophisticated-release-patterns.sh canary api-gateway v2.0.0

# 4. Gradually enable feature flag
./feature-flags/feature-flags-manager.sh rollout "api_v2" 100 10 60

# 5. Monitor and promote
./sophisticated-release-patterns.sh status

# 6. Cleanup old versions
./sophisticated-release-patterns.sh cleanup
```

### Emergency Rollback

```bash
# Immediate system rollback
./rollback-automation.sh rollback-system "Critical bug detected"

# Emergency feature flag shutdown
./feature-flags/feature-flags-manager.sh emergency

# Check system status
./sophisticated-release-patterns.sh status
```

---

This API reference provides complete documentation for integrating with the sophisticated release patterns system. For implementation examples and best practices, see the main README.md file.
