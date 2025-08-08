#!/bin/bash

# Jaeger Deployment Script for Kubernetes
# This script deploys Jaeger with all necessary components

set -e

echo "🚀 Deploying Jaeger distributed tracing system..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
OBSERVABILITY_NS="observability"
JAEGER_VERSION="1.35.0"

# Create observability namespace
create_namespace() {
    print_step "Creating observability namespace..."
    
    kubectl create namespace "$OBSERVABILITY_NS" --dry-run=client -o yaml | kubectl apply -f -
    
    # Label namespace for monitoring
    kubectl label namespace "$OBSERVABILITY_NS" monitoring=enabled --overwrite
    kubectl label namespace "$OBSERVABILITY_NS" name="$OBSERVABILITY_NS" --overwrite
    
    print_info "Namespace '$OBSERVABILITY_NS' created and labeled ✓"
}

# Deploy Jaeger Operator (Alternative 1)
deploy_jaeger_operator() {
    print_step "Deploying Jaeger Operator..."
    
    # Install Jaeger Operator
    kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.35.0/jaeger-operator.yaml -n "$OBSERVABILITY_NS" || true
    
    # Wait for operator to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger-operator -n "$OBSERVABILITY_NS"
    
    print_info "Jaeger Operator deployed ✓"
}

# Deploy Jaeger All-in-One (Simpler approach)
deploy_jaeger_all_in_one() {
    print_step "Deploying Jaeger All-in-One..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: $OBSERVABILITY_NS
  labels:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: all-in-one
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
      app.kubernetes.io/name: jaeger
      app.kubernetes.io/component: all-in-one
  template:
    metadata:
      labels:
        app: jaeger
        app.kubernetes.io/name: jaeger
        app.kubernetes.io/component: all-in-one
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "16686"
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:$JAEGER_VERSION
        args:
          - --memory.max-traces=50000
          - --query.base-path=/
          - --log-level=info
        ports:
        - containerPort: 16686
          protocol: TCP
          name: query
        - containerPort: 14268
          protocol: TCP
          name: collector
        - containerPort: 6831
          protocol: UDP
          name: agent-compact
        - containerPort: 6832
          protocol: UDP
          name: agent-binary
        - containerPort: 5778
          protocol: TCP
          name: config-rest
        - containerPort: 14250
          protocol: TCP
          name: grpc
        env:
        - name: COLLECTOR_ZIPKIN_HTTP_PORT
          value: "9411"
        - name: MEMORY_MAX_TRACES
          value: "50000"
        - name: QUERY_BASE_PATH
          value: "/"
        resources:
          limits:
            memory: "400Mi"
            cpu: "200m"
          requests:
            memory: "200Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /
            port: 16686
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 16686
          initialDelaySeconds: 30
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-query
  namespace: $OBSERVABILITY_NS
  labels:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: query
spec:
  type: ClusterIP
  ports:
  - name: query-http
    port: 16686
    protocol: TCP
    targetPort: 16686
  selector:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: all-in-one
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: $OBSERVABILITY_NS
  labels:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: collector
spec:
  type: ClusterIP
  ports:
  - name: jaeger-collector-http
    port: 14268
    protocol: TCP
    targetPort: 14268
  - name: jaeger-collector-grpc
    port: 14250
    protocol: TCP
    targetPort: 14250
  selector:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: all-in-one
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-agent
  namespace: $OBSERVABILITY_NS
  labels:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: agent
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: agent-zipkin-thrift
    port: 5775
    protocol: UDP
    targetPort: 5775
  - name: agent-compact
    port: 6831
    protocol: UDP
    targetPort: 6831
  - name: agent-binary
    port: 6832
    protocol: UDP
    targetPort: 6832
  - name: agent-configs
    port: 5778
    protocol: TCP
    targetPort: 5778
  selector:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: all-in-one
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-external
  namespace: $OBSERVABILITY_NS
  labels:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: query
spec:
  type: LoadBalancer
  ports:
  - name: query-http
    port: 16686
    protocol: TCP
    targetPort: 16686
  selector:
    app: jaeger
    app.kubernetes.io/name: jaeger
    app.kubernetes.io/component: all-in-one
EOF

    print_info "Jaeger All-in-One deployment created ✓"
}

# Wait for Jaeger to be ready
wait_for_jaeger() {
    print_step "Waiting for Jaeger to be ready..."
    
    # Wait for deployment to be available
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n "$OBSERVABILITY_NS"
    
    # Wait a bit more for services to be ready
    sleep 30
    
    print_info "Jaeger is ready ✓"
}

# Get Jaeger URLs
get_jaeger_urls() {
    print_step "Getting Jaeger access URLs..."
    
    # Get external LoadBalancer URL
    JAEGER_EXTERNAL_URL=""
    for i in {1..30}; do
        JAEGER_HOST=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -z "$JAEGER_HOST" ]; then
            JAEGER_HOST=$(kubectl get service jaeger-external -n "$OBSERVABILITY_NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        fi
        
        if [ -n "$JAEGER_HOST" ]; then
            JAEGER_EXTERNAL_URL="http://$JAEGER_HOST:16686"
            break
        fi
        
        echo "Waiting for LoadBalancer... ($i/30)"
        sleep 10
    done
    
    # Get internal cluster URLs
    JAEGER_QUERY_URL="http://jaeger-query.$OBSERVABILITY_NS.svc.cluster.local:16686"
    JAEGER_COLLECTOR_URL="http://jaeger-collector.$OBSERVABILITY_NS.svc.cluster.local:14268"
    JAEGER_AGENT_HOST="jaeger-agent.$OBSERVABILITY_NS.svc.cluster.local"
    
    print_info "Jaeger URLs obtained ✓"
}

# Verify Jaeger deployment
verify_jaeger() {
    print_step "Verifying Jaeger deployment..."
    
    # Check if pods are running
    JAEGER_POD=$(kubectl get pods -n "$OBSERVABILITY_NS" -l app=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$JAEGER_POD" ]; then
        POD_STATUS=$(kubectl get pod "$JAEGER_POD" -n "$OBSERVABILITY_NS" -o jsonpath='{.status.phase}')
        if [ "$POD_STATUS" = "Running" ]; then
            print_info "Jaeger pod is running ✓"
        else
            print_warning "Jaeger pod status: $POD_STATUS"
        fi
    else
        print_error "No Jaeger pods found"
        return 1
    fi
    
    # Test internal connectivity
    kubectl run jaeger-test --image=curlimages/curl --rm -i --restart=Never -- \
        curl -s "$JAEGER_QUERY_URL/api/health" >/dev/null && \
        print_info "Jaeger internal connectivity verified ✓" || \
        print_warning "Jaeger internal connectivity test failed"
}

# Print deployment summary
print_summary() {
    echo
    echo "======================================"
    echo "🎉 Jaeger Deployment Complete!"
    echo "======================================"
    
    print_info "Jaeger Components Deployed:"
    echo "  • Jaeger All-in-One (Query + Collector + Agent)"
    echo "  • Internal cluster services"
    echo "  • External LoadBalancer access"
    
    echo
    print_info "Access URLs:"
    if [ -n "$JAEGER_EXTERNAL_URL" ]; then
        echo "  • External Jaeger UI: $JAEGER_EXTERNAL_URL"
    else
        echo "  • External Jaeger UI: Pending LoadBalancer assignment"
        echo "    Check with: kubectl get svc jaeger-external -n $OBSERVABILITY_NS"
    fi
    echo "  • Internal Query: $JAEGER_QUERY_URL"
    echo "  • Internal Collector: $JAEGER_COLLECTOR_URL"
    echo "  • Internal Agent: $JAEGER_AGENT_HOST:6832"
    
    echo
    print_info "Environment Variables for Microservices:"
    echo "  JAEGER_AGENT_HOST=$JAEGER_AGENT_HOST"
    echo "  JAEGER_AGENT_PORT=6832"
    echo "  JAEGER_COLLECTOR_URL=$JAEGER_COLLECTOR_URL/api/traces"
    
    echo
    print_info "Next Steps:"
    echo "  1. Wait for LoadBalancer IP assignment (may take 5-10 minutes)"
    echo "  2. Access Jaeger UI using the external URL"
    echo "  3. Deploy your microservices with tracing enabled:"
    echo "     ./tracing/scripts/deploy-jaeger-enabled.sh"
    echo "  4. Generate test traces:"
    echo "     ./tracing/scripts/test-jaeger-tracing.sh"
    echo
}

# Main deployment flow
main() {
    echo "🎯 Jaeger Deployment Started"
    echo "Target namespace: $OBSERVABILITY_NS"
    echo "Jaeger version: $JAEGER_VERSION"
    echo
    
    create_namespace
    deploy_jaeger_all_in_one
    wait_for_jaeger
    get_jaeger_urls
    verify_jaeger
    print_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace=*)
            OBSERVABILITY_NS="${1#*=}"
            shift
            ;;
        --version=*)
            JAEGER_VERSION="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --namespace=NAME  Set observability namespace (default: observability)"
            echo "  --version=VER     Set Jaeger version (default: 1.35.0)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main deployment
main
