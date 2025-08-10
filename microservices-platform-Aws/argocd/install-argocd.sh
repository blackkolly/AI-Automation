#!/bin/bash

echo "🚀 Installing ArgoCD..."

# Create namespace
kubectl apply -f namespace.yaml

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Change ArgoCD server service to NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30080, "name": "http"}, {"port": 443, "nodePort": 30443, "name": "https"}]}}'

# Get initial admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "✅ ArgoCD Installation Complete!"
echo "🌐 Access ArgoCD at: http://localhost:30080"
echo "👤 Username: admin"
echo "🔐 Password: $ARGOCD_PASSWORD"
echo ""
echo "💡 To change password: argocd account update-password"
echo ""
