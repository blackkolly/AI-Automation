# 🔧 Troubleshooting Guide

## Sophisticated Release Patterns Troubleshooting

This comprehensive guide helps you diagnose and resolve common issues with sophisticated release patterns.

---

## 🚨 Emergency Procedures

### Immediate Actions for Critical Issues

#### System-Wide Emergency
```bash
# 1. Emergency rollback of all services
./rollback-automation.sh rollback-system "EMERGENCY: Critical system failure"

# 2. Disable all feature flags
./feature-flags/feature-flags-manager.sh emergency

# 3. Check system status
./sophisticated-release-patterns.sh status

# 4. Verify services are responding
for service in api-gateway auth-service product-service order-service; do
  ./rollback-automation.sh health-check $service
done
```

#### Single Service Emergency
```bash
# 1. Immediate service rollback
./rollback-automation.sh rollback-blue-green api-gateway "EMERGENCY: Service failure"

# 2. Scale down problematic deployment
kubectl scale deployment api-gateway-blue --replicas=0 -n microservices

# 3. Route traffic to stable version
kubectl patch service api-gateway -n microservices -p '{"spec":{"selector":{"version":"green"}}}'

# 4. Verify service recovery
./rollback-automation.sh health-check api-gateway
```

---

## 🔍 Diagnostic Tools

### System Health Check
```bash
#!/bin/bash
# Quick system health diagnostic

echo "=== SYSTEM HEALTH DIAGNOSTIC ==="
echo "Date: $(date)"
echo "Namespace: microservices"
echo ""

# Check cluster connectivity
echo "🔗 Cluster Connectivity:"
kubectl cluster-info --request-timeout=10s || echo "❌ Cannot connect to cluster"
echo ""

# Check namespace
echo "🏷️ Namespace Status:"
kubectl get namespace microservices || echo "❌ Namespace not found"
echo ""

# Check nodes
echo "🖥️ Node Status:"
kubectl get nodes -o wide
echo ""

# Check deployments
echo "📦 Deployment Status:"
kubectl get deployments -n microservices -o wide
echo ""

# Check services
echo "🌐 Service Status:"
kubectl get services -n microservices -o wide
echo ""

# Check pods
echo "🐳 Pod Status:"
kubectl get pods -n microservices -o wide
echo ""

# Check feature flags service
echo "🏁 Feature Flags Service:"
if kubectl get pods -n microservices -l app=feature-flags-service --no-headers 2>/dev/null | grep -q "Running"; then
  echo "✅ Feature flags service is running"
  FF_IP=$(kubectl get service feature-flags-service -n microservices -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ -n "$FF_IP" ]]; then
    echo "📍 Service IP: $FF_IP"
    if curl -f -s -m 5 "http://$FF_IP:3000/health" > /dev/null 2>&1; then
      echo "✅ Health check passed"
    else
      echo "❌ Health check failed"
    fi
  fi
else
  echo "❌ Feature flags service not running"
fi
```

### Network Connectivity Test
```bash
#!/bin/bash
# Test network connectivity between services

echo "=== NETWORK CONNECTIVITY TEST ==="

services=("api-gateway" "auth-service" "product-service" "order-service" "feature-flags-service")

for service in "${services[@]}"; do
  echo "Testing $service..."
  
  # Get service IP
  SERVICE_IP=$(kubectl get service "$service" -n microservices -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  
  if [[ -n "$SERVICE_IP" && "$SERVICE_IP" != "None" ]]; then
    echo "  📍 Service IP: $SERVICE_IP"
    
    # Test different ports based on service
    case "$service" in
      "api-gateway")
        PORT=3000
        ;;
      "auth-service")
        PORT=3001
        ;;
      "product-service")
        PORT=3002
        ;;
      "order-service")
        PORT=3003
        ;;
      "feature-flags-service")
        PORT=3000
        ;;
    esac
    
    if curl -f -s -m 5 "http://$SERVICE_IP:$PORT/health" > /dev/null 2>&1; then
      echo "  ✅ Health endpoint responding"
    else
      echo "  ❌ Health endpoint not responding"
    fi
  else
    echo "  ❌ Service not found or no ClusterIP"
  fi
  echo ""
done
```

---

## 🐛 Common Issues and Solutions

### 1. Deployment Failures

#### Issue: Blue-Green Deployment Stuck
```bash
# Symptoms:
# - Deployment shows "Progressing" status for extended time
# - New pods not reaching Ready state
# - Traffic not switching between environments

# Diagnosis:
kubectl describe deployment api-gateway-blue -n microservices
kubectl get pods -n microservices -l app=api-gateway,version=blue
kubectl logs deployment/api-gateway-blue -n microservices --tail=50

# Common causes and solutions:

# 1. Image pull failures
kubectl describe pod <pod-name> -n microservices
# Solution: Check image name/tag, registry credentials
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=your-username \
  --docker-password=your-password

# 2. Resource constraints
kubectl top nodes
kubectl describe nodes
# Solution: Increase node capacity or adjust resource requests

# 3. Health check failures
kubectl logs <pod-name> -n microservices
# Solution: Fix application startup issues or adjust health check parameters

# 4. Configuration errors
kubectl get configmaps -n microservices
kubectl describe configmap <configmap-name> -n microservices
# Solution: Verify configuration values

# Emergency fix:
./rollback-automation.sh rollback-blue-green api-gateway "Deployment stuck"
```

#### Issue: Canary Deployment Not Progressing
```bash
# Symptoms:
# - Canary pods running but not receiving traffic
# - Traffic percentage not changing
# - Monitoring shows no canary metrics

# Diagnosis:
kubectl get services -n microservices -l app=api-gateway
kubectl describe service api-gateway-canary -n microservices
kubectl get endpoints api-gateway-canary -n microservices

# Common causes and solutions:

# 1. Service selector mismatch
kubectl get pods -n microservices -l app=api-gateway,version=canary --show-labels
# Solution: Ensure pod labels match service selector

# 2. Ingress/Load balancer configuration
kubectl get ingress -n microservices
kubectl describe ingress api-gateway-ingress -n microservices
# Solution: Update ingress rules for canary routing

# 3. Service mesh configuration (if using Istio/Linkerd)
kubectl get virtualservice -n microservices
kubectl get destinationrule -n microservices
# Solution: Update service mesh routing rules

# Emergency fix:
./canary/canary-deploy.sh rollback api-gateway
```

### 2. Feature Flags Issues

#### Issue: Feature Flags Service Not Responding
```bash
# Symptoms:
# - Feature flag evaluations timing out
# - Service health checks failing
# - Applications cannot reach feature flags service

# Diagnosis:
kubectl get pods -n microservices -l app=feature-flags-service
kubectl logs deployment/feature-flags-service -n microservices --tail=50
kubectl describe service feature-flags-service -n microservices

# Common causes and solutions:

# 1. Service not running
kubectl get deployment feature-flags-service -n microservices
# Solution: Restart deployment
kubectl rollout restart deployment/feature-flags-service -n microservices

# 2. ConfigMap issues
kubectl get configmap feature-flags -n microservices
kubectl describe configmap feature-flags -n microservices
# Solution: Validate JSON configuration
kubectl get configmap feature-flags -n microservices -o jsonpath='{.data.flags\.json}' | jq .

# 3. Network connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- sh
# Inside pod: curl http://feature-flags-service:3000/health

# Emergency fix:
./feature-flags/feature-flags-manager.sh deploy
```

#### Issue: Feature Flag Evaluations Wrong
```bash
# Symptoms:
# - Flags returning unexpected values
# - User targeting not working correctly
# - Rollout percentages not applied

# Diagnosis:
./feature-flags/feature-flags-manager.sh list
./feature-flags/feature-flags-manager.sh status analytics user123 production us 1.2.0

# Debug specific flag evaluation:
FF_SERVICE_IP=$(kubectl get service feature-flags-service -n microservices -o jsonpath='{.spec.clusterIP}')
curl -s "http://$FF_SERVICE_IP:3000/flag/analytics?userId=user123&environment=production" | jq .

# Common causes and solutions:

# 1. Configuration errors
kubectl get configmap feature-flags -n microservices -o jsonpath='{.data.flags\.json}' | jq .features.analytics
# Solution: Fix configuration and reload
./feature-flags/feature-flags-manager.sh reload

# 2. Context parameters missing
# Solution: Ensure all required context is provided in API calls

# 3. Constraint logic errors
# Solution: Review and test constraint logic with various user contexts

# Emergency fix:
./feature-flags/feature-flags-manager.sh update analytics true 100
```

### 3. Rollback Issues

#### Issue: Automatic Rollback Not Triggering
```bash
# Symptoms:
# - High error rates but no rollback
# - Monitoring detects issues but rollback doesn't execute
# - Rollback scripts exit without action

# Diagnosis:
ps aux | grep rollback-automation
./rollback-automation.sh health-check api-gateway
echo $AUTO_ROLLBACK

# Common causes and solutions:

# 1. Auto-rollback disabled
export AUTO_ROLLBACK=true
# Solution: Enable auto-rollback globally or per deployment

# 2. Threshold not met
export ERROR_THRESHOLD=5
export CRITICAL_ERROR_THRESHOLD=10
# Solution: Adjust thresholds based on your requirements

# 3. Monitoring script not running
./rollback-automation.sh monitor api-gateway blue-green 600 &
# Solution: Ensure monitoring is started with deployment

# 4. Health check failures
./rollback-automation.sh health-check api-gateway
# Solution: Fix underlying service issues or adjust health check logic

# Manual trigger:
./rollback-automation.sh rollback-blue-green api-gateway "Manual intervention"
```

#### Issue: Rollback Fails to Complete
```bash
# Symptoms:
# - Rollback initiated but traffic still going to new version
# - Old version not scaling up
# - Services not responding after rollback

# Diagnosis:
kubectl get deployments -n microservices -l app=api-gateway
kubectl get services -n microservices -l app=api-gateway
kubectl rollout status deployment/api-gateway-green -n microservices

# Common causes and solutions:

# 1. Service selector not updated
kubectl get service api-gateway -n microservices -o jsonpath='{.spec.selector}'
# Solution: Manually update service selector
kubectl patch service api-gateway -n microservices -p '{"spec":{"selector":{"version":"green"}}}'

# 2. Old version not available
kubectl get deployment api-gateway-green -n microservices
# Solution: Ensure previous version deployment exists and is healthy

# 3. Resource constraints preventing scale-up
kubectl describe nodes
kubectl top nodes
# Solution: Free up resources or add capacity

# Emergency fix:
kubectl scale deployment api-gateway-green --replicas=3 -n microservices
kubectl patch service api-gateway -n microservices -p '{"spec":{"selector":{"version":"green"}}}'
```

### 4. Monitoring and Alerting Issues

#### Issue: No Metrics Being Collected
```bash
# Symptoms:
# - Prometheus showing no data
# - Health checks not detecting issues
# - Dashboard empty or stale

# Diagnosis:
kubectl get pods -n monitoring
kubectl logs deployment/prometheus-server -n monitoring
curl -s "http://prometheus-server:9090/api/v1/query?query=up" | jq .

# Common causes and solutions:

# 1. Prometheus not scraping targets
kubectl get servicemonitor -n microservices
kubectl describe servicemonitor api-gateway -n microservices
# Solution: Ensure ServiceMonitor configuration is correct

# 2. Metrics endpoints not responding
kubectl get services -n microservices -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.ports[?(@.name=="metrics")].port}{"\n"}{end}'
# Solution: Verify metrics endpoints are exposed and responding

# 3. Network policy blocking scraping
kubectl get networkpolicy -n microservices
# Solution: Allow Prometheus to scrape metrics

# Fix monitoring:
kubectl apply -f monitoring/prometheus-config.yaml
kubectl rollout restart deployment/prometheus-server -n monitoring
```

---

## 🔧 Advanced Troubleshooting

### Performance Issues

#### High Memory Usage
```bash
# Diagnosis:
kubectl top pods -n microservices --sort-by=memory
kubectl describe pod <high-memory-pod> -n microservices

# Solutions:
# 1. Increase memory limits
kubectl patch deployment api-gateway -n microservices -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","resources":{"limits":{"memory":"1Gi"}}}]}}}}'

# 2. Investigate memory leaks
kubectl exec -it <pod-name> -n microservices -- sh
# Inside pod: top, ps aux, check application logs

# 3. Enable memory profiling
# Add profiling endpoints to application
```

#### High CPU Usage
```bash
# Diagnosis:
kubectl top pods -n microservices --sort-by=cpu
kubectl describe hpa -n microservices

# Solutions:
# 1. Scale horizontally
kubectl scale deployment api-gateway --replicas=5 -n microservices

# 2. Investigate CPU bottlenecks
kubectl exec -it <pod-name> -n microservices -- sh
# Inside pod: top, iostat, check application metrics

# 3. Optimize application code
# Profile application and optimize hot paths
```

### Network Issues

#### DNS Resolution Problems
```bash
# Diagnosis:
kubectl run test-pod --image=busybox -it --rm -- sh
# Inside pod:
nslookup api-gateway.microservices.svc.cluster.local
nslookup feature-flags-service.microservices.svc.cluster.local

# Solutions:
# 1. Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs deployment/coredns -n kube-system

# 2. Verify service endpoints
kubectl get endpoints -n microservices

# 3. Check DNS policy
kubectl get pod <pod-name> -n microservices -o jsonpath='{.spec.dnsPolicy}'
```

#### Service Mesh Issues (if applicable)
```bash
# Diagnosis for Istio:
kubectl get virtualservice -n microservices
kubectl get destinationrule -n microservices
istioctl proxy-status

# Solutions:
# 1. Check sidecar injection
kubectl get pods -n microservices -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.containers[*].name}{"\n"}{end}'

# 2. Verify mTLS configuration
istioctl authn tls-check api-gateway.microservices.svc.cluster.local

# 3. Check traffic policies
kubectl describe virtualservice api-gateway -n microservices
```

### Storage Issues

#### ConfigMap/Secret Problems
```bash
# Diagnosis:
kubectl get configmaps -n microservices
kubectl describe configmap feature-flags -n microservices

# Validate JSON configuration:
kubectl get configmap feature-flags -n microservices -o jsonpath='{.data.flags\.json}' | jq . || echo "Invalid JSON"

# Solutions:
# 1. Fix JSON syntax
kubectl create configmap feature-flags --from-file=flags.json=corrected-flags.json -n microservices --dry-run=client -o yaml | kubectl apply -f -

# 2. Reload configuration
./feature-flags/feature-flags-manager.sh reload

# 3. Restart dependent pods
kubectl rollout restart deployment/feature-flags-service -n microservices
```

---

## 📊 Monitoring and Debugging Tools

### Custom Debug Script
```bash
#!/bin/bash
# comprehensive-debug.sh - Complete system debugging

set -e

NAMESPACE="microservices"
DEBUG_OUTPUT="/tmp/debug-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$DEBUG_OUTPUT")
exec 2>&1

echo "=== COMPREHENSIVE DEBUG REPORT ==="
echo "Date: $(date)"
echo "Namespace: $NAMESPACE"
echo "Output: $DEBUG_OUTPUT"
echo ""

# System overview
echo "### SYSTEM OVERVIEW ###"
kubectl version --short
kubectl cluster-info
kubectl get nodes -o wide
echo ""

# Namespace resources
echo "### NAMESPACE RESOURCES ###"
kubectl get all -n "$NAMESPACE" -o wide
echo ""

# Detailed pod information
echo "### POD DETAILS ###"
for pod in $(kubectl get pods -n "$NAMESPACE" --no-headers | awk '{print $1}'); do
  echo "--- Pod: $pod ---"
  kubectl describe pod "$pod" -n "$NAMESPACE"
  echo ""
  
  # Get recent logs
  echo "--- Logs for $pod ---"
  kubectl logs "$pod" -n "$NAMESPACE" --tail=20 --previous=false 2>/dev/null || echo "No logs available"
  echo ""
done

# Service endpoints
echo "### SERVICE ENDPOINTS ###"
kubectl get endpoints -n "$NAMESPACE"
echo ""

# ConfigMaps and Secrets
echo "### CONFIGMAPS ###"
kubectl get configmaps -n "$NAMESPACE"
for cm in $(kubectl get configmaps -n "$NAMESPACE" --no-headers | awk '{print $1}'); do
  echo "--- ConfigMap: $cm ---"
  kubectl describe configmap "$cm" -n "$NAMESPACE"
  echo ""
done

# Resource usage
echo "### RESOURCE USAGE ###"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics server not available"
echo ""

# Events
echo "### RECENT EVENTS ###"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20
echo ""

echo "=== DEBUG REPORT COMPLETE ==="
echo "Output saved to: $DEBUG_OUTPUT"
```

### Performance Monitoring Script
```bash
#!/bin/bash
# performance-monitor.sh - Monitor system performance

NAMESPACE="microservices"
DURATION=${1:-300}  # 5 minutes default
INTERVAL=30

echo "Monitoring performance for $DURATION seconds (interval: $INTERVAL)"

end_time=$(($(date +%s) + DURATION))

while [[ $(date +%s) -lt $end_time ]]; do
  echo "=== $(date) ==="
  
  # Pod resource usage
  kubectl top pods -n "$NAMESPACE" --no-headers | while read line; do
    echo "Pod: $line"
  done
  
  # Node resource usage
  kubectl top nodes --no-headers | while read line; do
    echo "Node: $line"
  done
  
  # Service health checks
  for service in api-gateway auth-service product-service order-service feature-flags-service; do
    if ./rollback-automation.sh health-check "$service" >/dev/null 2>&1; then
      echo "Service $service: ✅ Healthy"
    else
      echo "Service $service: ❌ Unhealthy"
    fi
  done
  
  echo ""
  sleep $INTERVAL
done
```

---

## 🚀 Quick Fixes

### Restart All Services
```bash
#!/bin/bash
# restart-all-services.sh

services=("api-gateway" "auth-service" "product-service" "order-service" "feature-flags-service")

for service in "${services[@]}"; do
  echo "Restarting $service..."
  kubectl rollout restart "deployment/$service" -n microservices
  kubectl rollout status "deployment/$service" -n microservices --timeout=300s
  echo "✅ $service restarted"
done
```

### Reset Feature Flags to Safe State
```bash
#!/bin/bash
# reset-feature-flags.sh

echo "Resetting all feature flags to safe state..."

# Disable all experimental flags
./feature-flags/feature-flags-manager.sh update "newUserInterface" false 0
./feature-flags/feature-flags-manager.sh update "machineLearning" false 0

# Set production flags to conservative values
./feature-flags/feature-flags-manager.sh update "analytics" true 50
./feature-flags/feature-flags-manager.sh update "caching" true 25
./feature-flags/feature-flags-manager.sh update "rateLimiting" true 10

echo "✅ Feature flags reset to safe state"
```

### Emergency Scale Down
```bash
#!/bin/bash
# emergency-scale-down.sh

echo "Emergency scale down of all deployments..."

# Scale down blue-green deployments
kubectl scale deployment api-gateway-blue --replicas=0 -n microservices 2>/dev/null || true
kubectl scale deployment api-gateway-green --replicas=1 -n microservices 2>/dev/null || true

# Scale down canary deployments
kubectl scale deployment api-gateway-canary --replicas=0 -n microservices 2>/dev/null || true
kubectl scale deployment api-gateway-stable --replicas=2 -n microservices 2>/dev/null || true

# Ensure stable versions are running
for service in auth-service product-service order-service; do
  kubectl scale "deployment/$service" --replicas=1 -n microservices
done

echo "✅ Emergency scale down completed"
```

---

## 📞 Getting Help

### When to Escalate

#### Immediate Escalation Required
- Data corruption or loss
- Security breaches
- Payment processing failures
- Complete system outage (>95% error rate)
- Compliance violations

#### Standard Escalation
- Performance degradation (>50% slower)
- High error rates (>10%)
- Multiple service failures
- Rollback failures
- Monitoring system failures

### Information to Gather Before Escalating

```bash
# Run the comprehensive debug script
./comprehensive-debug.sh

# Gather deployment information
./sophisticated-release-patterns.sh status > status-report.txt

# Collect recent logs
kubectl logs deployment/api-gateway -n microservices --since=1h > api-gateway-logs.txt

# Export current configurations
kubectl get configmaps -n microservices -o yaml > configmaps-backup.yaml
kubectl get secrets -n microservices -o yaml > secrets-backup.yaml

# Create incident report
cat << EOF > incident-report.txt
Incident Report
===============
Date: $(date)
Reporter: $(whoami)
Severity: [Critical/High/Medium/Low]

Description:
[Describe the issue]

Steps to Reproduce:
[List steps that led to the issue]

Impact:
[Describe business/user impact]

Actions Taken:
[List troubleshooting steps performed]

Current Status:
[Describe current system state]

Additional Information:
[Any other relevant details]
EOF
```

### Support Channels

1. **Emergency Hotline**: For critical issues
2. **Team Chat**: For real-time collaboration
3. **Incident Management**: For formal incident tracking
4. **Documentation**: Check runbooks and procedures first

---

## 🎯 Prevention Strategies

### Proactive Monitoring
```bash
# Set up comprehensive monitoring
./rollback-automation.sh setup-webhook 8080
./rollback-automation.sh monitor-all 86400 &  # 24 hours

# Configure alerting thresholds
export ERROR_THRESHOLD=3
export CRITICAL_ERROR_THRESHOLD=5
export AUTO_ROLLBACK=true
```

### Regular Health Checks
```bash
# Daily health check routine
#!/bin/bash
# daily-health-check.sh

./sophisticated-release-patterns.sh status
./rollback-automation.sh health-check api-gateway
./feature-flags/feature-flags-manager.sh list

# Check resource usage
kubectl top nodes
kubectl top pods -n microservices

# Verify all services responding
for service in api-gateway auth-service product-service order-service; do
  ./rollback-automation.sh health-check "$service"
done
```

### Automated Testing
```bash
# Continuous testing pipeline
#!/bin/bash
# continuous-testing.sh

# Run smoke tests every hour
while true; do
  ./smoke-tests.sh microservices
  sleep 3600
done &

# Run health checks every 5 minutes
while true; do
  ./rollback-automation.sh monitor-all 300
  sleep 300
done &
```

---

This troubleshooting guide covers the most common issues you'll encounter with sophisticated release patterns. Keep this guide handy and update it with new issues and solutions as you encounter them in your environment.
