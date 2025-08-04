#!/bin/bash

echo "📊 Installing ELK Stack for Centralized Logging..."

# Create logging namespace
echo "Creating logging namespace..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Install Elasticsearch
echo "Installing Elasticsearch..."
kubectl apply -f elasticsearch.yaml

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# Install Kibana
echo "Installing Kibana..."
kubectl apply -f kibana.yaml

# Install Filebeat
echo "Installing Filebeat..."
kubectl apply -f filebeat.yaml

# Install Logstash
echo "Installing Logstash..."
kubectl apply -f logstash.yaml

# Configure log forwarding
echo "Configuring log forwarding..."
kubectl apply -f log-forwarding.yaml

echo "✅ ELK Stack installation completed!"
echo ""
echo "Access URLs:"
echo "- Kibana: http://localhost:5601 (after port-forward)"
echo "- Elasticsearch: http://localhost:9200 (after port-forward)"
echo ""
echo "Port Forward Commands:"
echo "kubectl port-forward svc/kibana 5601:5601 -n logging"
echo "kubectl port-forward svc/elasticsearch 9200:9200 -n logging"
echo ""
echo "Verify installation:"
echo "kubectl get pods -n logging"
echo "kubectl logs -f deployment/kibana -n logging"
