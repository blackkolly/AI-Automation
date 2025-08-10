#!/bin/bash

echo "📊 Installing ELK Stack for Logging..."

# Create logging namespace
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Install Elasticsearch
echo "🔍 Installing Elasticsearch..."
kubectl apply -f elasticsearch.yaml

# Install Kibana
echo "📈 Installing Kibana..."
kubectl apply -f kibana.yaml

# Install Filebeat as DaemonSet
echo "📝 Installing Filebeat..."
kubectl apply -f filebeat.yaml

# Install Logstash
echo "⚙️ Installing Logstash..."
kubectl apply -f logstash.yaml

# Wait for services to be ready
echo "⏳ Waiting for ELK stack to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/elasticsearch -n logging
kubectl wait --for=condition=available --timeout=300s deployment/kibana -n logging

# Expose Kibana via NodePort
kubectl patch svc kibana -n logging -p '{"spec": {"type": "NodePort", "ports": [{"port": 5601, "nodePort": 30561, "name": "http"}]}}'

echo ""
echo "✅ ELK Stack Installation Complete!"
echo "🌐 Kibana Dashboard: http://localhost:30561"
echo "📝 Logs are being collected from all microservices"
echo ""
echo "💡 To view logs:"
echo "   1. Go to http://localhost:30561"
echo "   2. Create index pattern: filebeat-*"
echo "   3. View logs in Discover tab"
echo ""
