# Trivy Security Scanner Setup and Usage Guide

## 🔐 Overview

This directory contains comprehensive **Trivy security scanning** implementations for your microservices platform. Trivy is a comprehensive vulnerability scanner that can detect:

- **Vulnerabilities** in OS packages and language-specific packages
- **Misconfigurations** in IaC files (Kubernetes, Docker, Terraform)
- **Secrets** and sensitive information
- **License issues** in dependencies

## 📁 Directory Structure

```
microservices-local/security/
├── trivy-install.sh           # Trivy installation script
├── trivy-scan.sh              # Container image scanning
├── trivy-k8s-scan.sh          # Kubernetes cluster scanning
├── trivy-ci-cd.sh             # CI/CD integration templates
├── trivy-config.yaml          # Trivy configuration file
├── run-comprehensive-scan.sh  # Complete security assessment
├── ci-cd-templates/           # CI/CD pipeline templates
├── helm-charts/               # Helm charts for Trivy Operator
└── reports/                   # Generated scan reports
```

## 🚀 Quick Start

### 1. Install Trivy
```bash
chmod +x trivy-install.sh
./trivy-install.sh
```

### 2. Run Comprehensive Security Scan
```bash
chmod +x run-comprehensive-scan.sh
./run-comprehensive-scan.sh
```

### 3. Scan Kubernetes Cluster
```bash
chmod +x trivy-k8s-scan.sh
./trivy-k8s-scan.sh
```

### 4. Scan Container Images
```bash
chmod +x trivy-scan.sh
./trivy-scan.sh
```

## 📊 Available Scanning Types

### 🔍 File System Scanning
Scans your codebase for:
- Vulnerabilities in dependencies
- Hardcoded secrets
- Configuration issues
- License compliance

### 🐳 Container Image Scanning
Analyzes Docker images for:
- OS package vulnerabilities
- Application dependency issues
- Image configuration problems
- Embedded secrets

### ☸️ Kubernetes Scanning
Evaluates cluster security:
- Pod security configurations
- RBAC policies
- Network policies
- Resource configurations
- Workload security

## 🛠️ Configuration

### Trivy Configuration (`trivy-config.yaml`)
Customize scanning behavior:
- Severity levels to report
- File patterns to include/exclude
- Vulnerability databases
- Output formats

### Custom Policies
Create custom security policies for:
- Organization-specific requirements
- Compliance frameworks
- Custom vulnerability rules

## 📈 CI/CD Integration

### GitHub Actions
```yaml
# Copy ci-cd-templates/trivy-security-scan.yml to .github/workflows/
```

### Jenkins Pipeline
```groovy
// Use ci-cd-templates/Jenkinsfile-trivy
```

### GitLab CI
```yaml
# Copy ci-cd-templates/.gitlab-ci.yml to repository root
```

### Docker Compose (Local Development)
```bash
docker-compose -f ci-cd-templates/docker-compose-trivy.yml up
```

## 📋 Report Types

### 1. Vulnerability Reports
- **JSON**: Machine-readable format for automation
- **Table**: Human-readable console output
- **SARIF**: For GitHub Security tab integration

### 2. Configuration Reports
- Kubernetes security misconfigurations
- Docker best practices violations
- IaC security issues

### 3. Secret Detection Reports
- Hardcoded API keys
- Database credentials
- Private keys and certificates

### 4. License Reports
- License compatibility issues
- Forbidden license usage
- License compliance summary

## 🎯 Usage Examples

### Scan Specific Container Image
```bash
trivy image --config trivy-config.yaml node:18-alpine
```

### Scan Current Directory
```bash
trivy fs --config trivy-config.yaml .
```

### Scan Kubernetes Namespace
```bash
trivy k8s namespace/microservices
```

### Generate JSON Report
```bash
trivy fs --format json --output report.json .
```

## 🔧 Advanced Features

### 1. Custom Policies
Create organization-specific security policies:
```bash
# Add custom policies to policies/ directory
trivy fs --config-policy policies/ .
```

### 2. Ignore Files
Use `.trivyignore` to exclude specific vulnerabilities:
```
# Ignore specific CVE
CVE-2023-1234

# Ignore by path
**/test/**
```

### 3. Integration with Monitoring
- Export metrics to Prometheus
- Send alerts to Slack/Teams
- Integrate with SIEM systems

## 📊 Security Dashboard

### Metrics Tracked
- Vulnerability counts by severity
- Scan completion rates
- Mean time to remediation
- Security policy compliance

### Alerting
- Critical vulnerability detection
- New secret exposure
- Policy violations
- Scan failures

## 🔄 Automation Workflows

### Daily Scanning
```bash
# Add to crontab for daily scans
0 6 * * * /path/to/run-comprehensive-scan.sh
```

### Pre-commit Hooks
```bash
# Scan before git commits
trivy fs --exit-code 1 --severity HIGH,CRITICAL .
```

### Continuous Monitoring
- Deploy Trivy Operator in Kubernetes
- Real-time vulnerability detection
- Automatic policy enforcement

## 🚨 Security Recommendations

### 1. Immediate Actions
- Fix CRITICAL and HIGH severity vulnerabilities
- Remove exposed secrets
- Address configuration misconfigurations

### 2. Regular Practices
- Weekly vulnerability scans
- Monthly security reviews
- Quarterly policy updates

### 3. Long-term Strategy
- Implement security-first development
- Automate security in CI/CD
- Establish security metrics and KPIs

## 🆘 Troubleshooting

### Common Issues

1. **Trivy Database Update Fails**
   ```bash
   trivy image --reset
   trivy image --download-db-only
   ```

2. **Kubernetes Access Issues**
   ```bash
   kubectl auth can-i --list
   ```

3. **Large Report Sizes**
   ```bash
   # Filter by severity
   trivy fs --severity HIGH,CRITICAL .
   ```

## 📚 Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Container Security Guidelines](https://cloud.google.com/container-analysis/docs/container-analysis)

## 🔧 Support

For issues or questions:
1. Check the troubleshooting section
2. Review Trivy documentation
3. Open an issue in the project repository

---

**Note**: Regular security scanning is essential for maintaining a secure microservices platform. Make sure to integrate these tools into your development workflow and CI/CD pipeline.
