# Monitoring Stack Installation Script

#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Prometheus Monitoring Stack...${NC}"

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo update

# Create monitoring namespace
echo -e "${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus Stack (includes Prometheus, Grafana, AlertManager)
echo -e "${YELLOW}Installing Prometheus Stack...${NC}"
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.retentionSize=45GB \
  --set grafana.adminPassword=admin123 \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName=gp2 \
  --set grafana.persistence.size=10Gi \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=gp2 \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --wait

# Install Jaeger for distributed tracing
echo -e "${YELLOW}Installing Jaeger...${NC}"
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --set provisionDataStore.cassandra=false \
  --set provisionDataStore.elasticsearch=true \
  --set storage.type=elasticsearch \
  --set elasticsearch.deploy=true \
  --set elasticsearch.replicas=1 \
  --set elasticsearch.minimumMasterNodes=1 \
  --set elasticsearch.resources.requests.memory=1Gi \
  --set elasticsearch.resources.limits.memory=2Gi \
  --wait

# Install Loki for log aggregation
echo -e "${YELLOW}Installing Loki...${NC}"
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.storageClassName=gp2 \
  --set loki.persistence.size=50Gi \
  --set promtail.enabled=true \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set prometheus.alertmanager.enabled=false \
  --wait

# Install Fluent Bit for log collection
echo -e "${YELLOW}Installing Fluent Bit...${NC}"
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  --set config.outputs="[OUTPUT]\n    Name loki\n    Match *\n    Host loki.monitoring.svc.cluster.local\n    Port 3100\n    Labels job=fluent-bit\n    Auto_Kubernetes_Labels on" \
  --wait

# Apply custom configurations
echo -e "${YELLOW}Applying custom monitoring configurations...${NC}"
kubectl apply -f ./prometheus-config.yaml
kubectl apply -f ./grafana-dashboards.yaml
kubectl apply -f ./alerting-rules.yaml

# Create service monitors for our applications
echo -e "${YELLOW}Creating ServiceMonitors for applications...${NC}"
kubectl apply -f ./servicemonitors.yaml

# Install metrics-server if not present
echo -e "${YELLOW}Installing metrics-server...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for all deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-stack-kube-prom-operator -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-stack-grafana -n monitoring
kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=jaeger -n monitoring

# Get access information
echo -e "${GREEN}Monitoring stack installation completed!${NC}"
echo -e "${YELLOW}Access Information:${NC}"
echo "Prometheus: kubectl port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090 -n monitoring"
echo "Grafana: kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring (admin/admin123)"
echo "Jaeger: kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring"
echo "AlertManager: kubectl port-forward svc/prometheus-stack-kube-prom-alertmanager 9093:9093 -n monitoring"

echo -e "${GREEN}Monitoring stack is ready!${NC}"
