#!/bin/bash

# Comprehensive Security Scanner with Trivy
echo "🛡️  Comprehensive Security Scanner"
echo "=================================="

# Create all necessary directories
mkdir -p {reports,policies,configs}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to check if tools are installed
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check for Trivy installation methods
    if [ -f "./trivy-docker.sh" ]; then
        TRIVY_CMD="./trivy-docker.sh"
        echo "✅ Using Trivy Docker wrapper: ${TRIVY_CMD}"
    elif [ -f "~/bin/trivy-docker.sh" ]; then
        TRIVY_CMD="~/bin/trivy-docker.sh"
        echo "✅ Using Trivy Docker wrapper: ${TRIVY_CMD}"
    elif command -v ${TRIVY_CMD} &> /dev/null; then
        TRIVY_CMD="trivy"
        echo "✅ Using native Trivy: ${TRIVY_CMD}"
    else
        echo "❌ Trivy not found. Please run ./trivy-install-windows.sh first"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "⚠️  kubectl not found. Kubernetes scanning will be skipped."
        K8S_AVAILABLE=false
    else
        K8S_AVAILABLE=true
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "⚠️  Docker not found. Container scanning will be limited."
        DOCKER_AVAILABLE=false
    else
        DOCKER_AVAILABLE=true
    fi
    
    echo "✅ Prerequisites checked"
    echo ""
}

# Function to perform comprehensive file system scan
filesystem_scan() {
    echo "📁 File System Security Scan"
    echo "============================"
    
    # Scan current directory for vulnerabilities
    echo "🔍 Scanning for vulnerabilities..."
    ${TRIVY_CMD} fs --config trivy-config.yaml --format json --output "reports/filesystem_vulnerabilities_${TIMESTAMP}.json" .
    ${TRIVY_CMD} fs --config trivy-config.yaml --format table --output "reports/filesystem_vulnerabilities_${TIMESTAMP}.txt" .
    
    # Scan for secrets
    echo "🔐 Scanning for secrets..."
    ${TRIVY_CMD} fs --scanners secret --format json --output "reports/filesystem_secrets_${TIMESTAMP}.json" .
    ${TRIVY_CMD} fs --scanners secret --format table --output "reports/filesystem_secrets_${TIMESTAMP}.txt" .
    
    # Scan for configuration issues
    echo "⚙️  Scanning configurations..."
    ${TRIVY_CMD} fs --scanners config --format json --output "reports/filesystem_config_${TIMESTAMP}.json" .
    ${TRIVY_CMD} fs --scanners config --format table --output "reports/filesystem_config_${TIMESTAMP}.txt" .
    
    # Scan for license issues
    echo "📄 Scanning licenses..."
    ${TRIVY_CMD} fs --scanners license --format json --output "reports/filesystem_licenses_${TIMESTAMP}.json" .
    ${TRIVY_CMD} fs --scanners license --format table --output "reports/filesystem_licenses_${TIMESTAMP}.txt" .
    
    echo "✅ File system scan complete"
    echo ""
}

# Function to scan container images
container_scan() {
    echo "🐳 Container Image Security Scan"
    echo "==============================="
    
    if [[ "$DOCKER_AVAILABLE" == "true" ]]; then
        # Get list of local images
        LOCAL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -10)
        
        for image in $LOCAL_IMAGES; do
            if [[ "$image" != "<none>:<none>" ]]; then
                echo "📦 Scanning image: $image"
                
                # Clean image name for filename
                clean_name=$(echo "$image" | sed 's/[^a-zA-Z0-9]/_/g')
                
                # Vulnerability scan
                ${TRIVY_CMD} image --format json --output "reports/image_${clean_name}_vulns_${TIMESTAMP}.json" "$image"
                ${TRIVY_CMD} image --format table --output "reports/image_${clean_name}_vulns_${TIMESTAMP}.txt" "$image"
                
                # Configuration scan
                ${TRIVY_CMD} image --scanners config --format json --output "reports/image_${clean_name}_config_${TIMESTAMP}.json" "$image"
                
                # Secret scan
                ${TRIVY_CMD} image --scanners secret --format json --output "reports/image_${clean_name}_secrets_${TIMESTAMP}.json" "$image"
            fi
        done
    fi
    
    # Scan common base images used in microservices
    COMMON_IMAGES=("node:18-alpine" "nginx:alpine" "mongo:latest" "redis:alpine")
    
    for image in "${COMMON_IMAGES[@]}"; do
        echo "📦 Scanning common image: $image"
        clean_name=$(echo "$image" | sed 's/[^a-zA-Z0-9]/_/g')
        
        ${TRIVY_CMD} image --format json --output "reports/common_${clean_name}_${TIMESTAMP}.json" "$image"
        ${TRIVY_CMD} image --format table --output "reports/common_${clean_name}_${TIMESTAMP}.txt" "$image"
    done
    
    echo "✅ Container image scan complete"
    echo ""
}

# Function to scan Kubernetes cluster
kubernetes_scan() {
    if [[ "$K8S_AVAILABLE" == "true" ]]; then
        echo "☸️  Kubernetes Cluster Security Scan"
        echo "===================================="
        
        # Full cluster scan
        echo "🌐 Scanning entire cluster..."
        ${TRIVY_CMD} k8s --report all --format json --output "reports/k8s_cluster_full_${TIMESTAMP}.json" cluster
        ${TRIVY_CMD} k8s --report all --format table --output "reports/k8s_cluster_full_${TIMESTAMP}.txt" cluster
        
        # Namespace-specific scans
        NAMESPACES=($(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'))
        
        for ns in "${NAMESPACES[@]}"; do
            # Skip system namespaces for detailed scanning
            if [[ ! "$ns" =~ ^(kube-|kubernetes-) ]]; then
                echo "📂 Scanning namespace: $ns"
                
                ${TRIVY_CMD} k8s --report summary --format json --output "reports/k8s_ns_${ns}_${TIMESTAMP}.json" "namespace/$ns"
                ${TRIVY_CMD} k8s --report summary --format table --output "reports/k8s_ns_${ns}_${TIMESTAMP}.txt" "namespace/$ns"
            fi
        done
        
        echo "✅ Kubernetes scan complete"
        echo ""
    fi
}

# Function to generate comprehensive report
generate_report() {
    echo "📊 Generating Comprehensive Security Report"
    echo "=========================================="
    
    cat > "reports/comprehensive_security_report_${TIMESTAMP}.md" << EOF
# Comprehensive Security Report

**Generated:** $(date)  
**Timestamp:** ${TIMESTAMP}  
**Scanner:** Trivy  

## Executive Summary

This report contains a comprehensive security analysis of the microservices platform including:
- File system vulnerability scanning
- Container image security analysis
- Kubernetes cluster security assessment
- Configuration audit results
- Secret detection findings

## Critical Findings

### High/Critical Vulnerabilities
\`\`\`
$(find reports -name "*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH") | .VulnerabilityID + " (" + .Severity + "): " + .Title' {} \; 2>/dev/null | sort | uniq | head -20)
\`\`\`

### Detected Secrets
\`\`\`
$(find reports -name "*secrets*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Secrets[]? | .RuleID + ": " + .Title' {} \; 2>/dev/null | sort | uniq | head -10)
\`\`\`

### Configuration Issues
\`\`\`
$(find reports -name "*config*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL") | .ID + ": " + .Title' {} \; 2>/dev/null | sort | uniq | head -15)
\`\`\`

## Detailed Analysis

### File System Scan Results
- **Vulnerabilities:** See \`filesystem_vulnerabilities_${TIMESTAMP}.txt\`
- **Secrets:** See \`filesystem_secrets_${TIMESTAMP}.txt\`
- **Configuration:** See \`filesystem_config_${TIMESTAMP}.txt\`
- **Licenses:** See \`filesystem_licenses_${TIMESTAMP}.txt\`

### Container Image Analysis
$(if [[ "$DOCKER_AVAILABLE" == "true" ]]; then
    echo "- **Local Images:** Scanned $(ls reports/image_*_${TIMESTAMP}.txt 2>/dev/null | wc -l) local images"
fi)
- **Common Images:** Scanned base images for known vulnerabilities

### Kubernetes Security Assessment
$(if [[ "$K8S_AVAILABLE" == "true" ]]; then
    echo "- **Cluster Scan:** Full cluster security assessment completed"
    echo "- **Namespace Scans:** Individual namespace security reviews"
    echo "- **Workload Analysis:** Pod and deployment security configurations"
fi)

## Recommendations

1. **Immediate Actions:**
   - Patch all CRITICAL severity vulnerabilities
   - Remove or secure any exposed secrets
   - Fix HIGH severity configuration issues

2. **Short-term Actions:**
   - Update base images to latest secure versions
   - Implement pod security standards
   - Review and fix MEDIUM severity issues

3. **Long-term Actions:**
   - Establish regular security scanning schedule
   - Implement security policies in CI/CD pipeline
   - Set up automated vulnerability monitoring

## Files Generated

\`\`\`
$(ls -la reports/*${TIMESTAMP}* | grep -v "comprehensive_security_report")
\`\`\`

---
*Report generated by Trivy Security Scanner*
EOF

    echo "✅ Comprehensive report generated: reports/comprehensive_security_report_${TIMESTAMP}.md"
    echo ""
}

# Function to display summary
display_summary() {
    echo "📋 Security Scan Summary"
    echo "======================="
    
    echo "📁 Files generated:"
    ls -la reports/*${TIMESTAMP}* | awk '{print "   " $9}'
    
    echo ""
    echo "🔍 Quick stats:"
    
    # Count vulnerabilities by severity
    if ls reports/*vulnerabilities*${TIMESTAMP}.json 1> /dev/null 2>&1; then
        echo "   Critical vulnerabilities: $(find reports -name "*vulnerabilities*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL") | .VulnerabilityID' {} \; 2>/dev/null | wc -l)"
        echo "   High vulnerabilities: $(find reports -name "*vulnerabilities*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH") | .VulnerabilityID' {} \; 2>/dev/null | wc -l)"
    fi
    
    # Count secrets
    if ls reports/*secrets*${TIMESTAMP}.json 1> /dev/null 2>&1; then
        echo "   Secrets detected: $(find reports -name "*secrets*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Secrets[]? | .RuleID' {} \; 2>/dev/null | wc -l)"
    fi
    
    # Count config issues
    if ls reports/*config*${TIMESTAMP}.json 1> /dev/null 2>&1; then
        echo "   Config issues: $(find reports -name "*config*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Misconfigurations[]? | .ID' {} \; 2>/dev/null | wc -l)"
    fi
    
    echo ""
    echo "📄 Main report: reports/comprehensive_security_report_${TIMESTAMP}.md"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Review the comprehensive report"
    echo "   2. Address critical and high severity issues"
    echo "   3. Integrate scanning into CI/CD pipeline"
    echo "   4. Set up regular security scanning schedule"
}

# Main execution
main() {
    check_prerequisites
    filesystem_scan
    container_scan
    kubernetes_scan
    generate_report
    display_summary
    
    echo ""
    echo "🛡️  Comprehensive security scanning complete!"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
