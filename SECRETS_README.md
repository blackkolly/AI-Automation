# Secrets Management for Kubernetes Project

## Overview
This project contains sensitive configuration data that must be properly managed to maintain security.

## ⚠️ Security Notice
All `*.yaml` files containing actual secrets are **git-ignored** for security purposes.

## Template Files
The following template files are provided for setting up your environment:

- `secrets.yaml.template` - Basic secrets configuration
- `secrets-enhanced.yaml.template` - Advanced secrets with encryption policies
- `microservices-platform/Security/secrets.yaml.template` - Platform-specific secrets
- `microservices-platform/Security/secrets-enhanced.yaml.template` - Enhanced platform secrets

## Setup Instructions

### 1. Copy Template Files
```bash
# Copy templates to actual secrets files
cp secrets.yaml.template secrets.yaml
cp secrets-enhanced.yaml.template secrets-enhanced.yaml
cp microservices-platform/Security/secrets.yaml.template microservices-platform/Security/secrets.yaml
cp microservices-platform/Security/secrets-enhanced.yaml.template microservices-platform/Security/secrets-enhanced.yaml
```

### 2. Generate Your Secrets
Use base64 encoding for all secret values:

```bash
# Basic encoding
echo -n "your-secret-value" | base64

# Example for common secrets
echo -n "admin" | base64                    # YWRtaW4=
echo -n "password123" | base64             # cGFzc3dvcmQxMjM=
echo -n "microservices" | base64           # bWljcm9zZXJ2aWNlcw==
echo -n "super-secret-jwt-key" | base64    # c3VwZXItc2VjcmV0LWp3dC1rZXk=
```

### 3. Update Template Values
Replace all placeholder values in the copied files:
- `<BASE64_ENCODED_USERNAME>` → Your base64 encoded username
- `<BASE64_ENCODED_PASSWORD>` → Your base64 encoded password
- `<BASE64_ENCODED_JWT_SECRET>` → Your base64 encoded JWT secret
- And so on...

### 4. Apply to Kubernetes
```bash
# Apply secrets to your cluster
kubectl apply -f secrets.yaml
kubectl apply -f secrets-enhanced.yaml
kubectl apply -f microservices-platform/Security/secrets.yaml
kubectl apply -f microservices-platform/Security/secrets-enhanced.yaml
```

## Security Best Practices

### ✅ DO:
- Use strong, unique passwords
- Rotate secrets regularly
- Use Kubernetes RBAC to limit access
- Consider using sealed-secrets or external secret management
- Keep template files in version control
- Use namespace isolation

### ❌ DON'T:
- Commit actual secrets to version control
- Use default or weak passwords
- Share secrets in plain text
- Store secrets in container images
- Use the same secrets across environments

## Secret Types Included

### Database Credentials
- MongoDB admin username/password
- Database names
- Connection strings

### API Keys & Tokens
- JWT signing secrets
- External API keys
- Internal service authentication

### TLS Certificates
- SSL/TLS certificates for HTTPS
- Private keys for encryption
- CA certificates

### Container Registry
- Docker registry authentication
- Image pull secrets

## Environment-Specific Setup

### Development
Use weak/default secrets for local development:
```bash
# Development secrets (NOT for production!)
echo -n "dev-admin" | base64
echo -n "dev-password" | base64
```

### Production
Use strong, randomly generated secrets:
```bash
# Generate strong passwords
openssl rand -base64 32 | base64 -w 0
```

## Troubleshooting

### Invalid Base64 Encoding
```bash
# Decode to verify
echo "your-base64-string" | base64 -d
```

### Secret Not Found
```bash
# Check if secret exists
kubectl get secrets -n microservices
kubectl describe secret mongodb-credentials -n microservices
```

### Permission Denied
```bash
# Check RBAC permissions
kubectl auth can-i get secrets --as=system:serviceaccount:microservices:default
```

## Additional Security Tools

This project includes:
- Trivy vulnerability scanning
- Network policies
- Pod security policies
- RBAC configurations
- Istio security policies

Refer to the `Security/` directories for detailed security implementations.
