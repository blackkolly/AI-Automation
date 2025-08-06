#!/bin/bash

echo "🚀 Starting Observability Dashboard Port Forwards"
echo "================================================="

# Function to start port forward in background
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local name=$5
    
    echo "Starting $name on http://localhost:$local_port"
    kubectl port-forward -n $namespace svc/$service $local_port:$remote_port > /dev/null 2>&1 &
    local pid=$!
    echo "  PID: $pid"
    sleep 2
    
    # Check if port forward is working
    if kill -0 $pid 2>/dev/null; then
        echo "  ✅ $name is running"
    else
        echo "  ❌ $name failed to start"
    fi
}

# Start port forwards
start_port_forward "kiali" "istio-system" "20001" "20001" "Kiali Dashboard"
start_port_forward "grafana" "istio-system" "3001" "3000" "Grafana Dashboard" 
start_port_forward "jaeger-collector" "istio-system" "16686" "14268" "Jaeger Tracing"

echo ""
echo "📊 Dashboard URLs:"
echo "  🌐 Kiali (Service Mesh): http://localhost:20001"
echo "  📈 Grafana (Metrics): http://localhost:3001"
echo "  🔍 Jaeger (Tracing): http://localhost:16686"
echo ""
echo "🛑 To stop all port forwards:"
echo "  pkill -f 'kubectl port-forward'"
echo ""
echo "⏳ Port forwards are running in background..."
