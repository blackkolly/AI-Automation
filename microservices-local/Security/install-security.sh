#!/bin/bash

echo "🔐 Installing Security Components for Microservices Platform..."

# Create security namespace
echo "Creating security namespace..."
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -

# Apply RBAC configurations
echo "Applying RBAC configurations..."
kubectl apply -f rbac.yaml

# Apply network policies
echo "Applying network policies..."
kubectl apply -f network-policies.yaml

# Apply security secrets
echo "Applying security secrets..."
kubectl apply -f secrets.yaml

# Apply Pod Security Standards
echo "Applying Pod Security Standards..."
kubectl apply -f pod-security-standards.yaml

# Apply admission controllers configuration
echo "Applying admission controllers..."
kubectl apply -f admission-controllers.yaml

echo "✅ Security components installation completed!"
echo ""
echo "Security Features Enabled:"
echo "- RBAC for fine-grained access control"
echo "- Network policies for traffic isolation"
echo "- Pod Security Standards for container security"
echo "- Admission controllers for policy enforcement"
echo "- Encrypted secrets management"
echo ""
echo "Next steps:"
echo "1. Verify security policies: kubectl get networkpolicies -n microservices"
echo "2. Check RBAC: kubectl get roles,rolebindings -n microservices"
echo "3. View secrets: kubectl get secrets -n microservices"
