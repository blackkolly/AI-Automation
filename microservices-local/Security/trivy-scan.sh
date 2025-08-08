#!/bin/bash

# Trivy Container and Image Scanning Script
echo "🔍 Trivy Container Security Scanning"
echo "===================================="

# Create reports directory
mkdir -p reports
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to scan Docker image
scan_image() {
    local image=$1
    local service_name=$2
    
    echo "📦 Scanning image: $image"
    
    # Vulnerability scan
    trivy image --format json --output "reports/${service_name}_vulnerabilities_${TIMESTAMP}.json" "$image"
    trivy image --format table --output "reports/${service_name}_vulnerabilities_${TIMESTAMP}.txt" "$image"
    
    # Configuration scan
    trivy config --format json --output "reports/${service_name}_config_${TIMESTAMP}.json" "$image"
    
    # Secret scan
    trivy image --scanners secret --format json --output "reports/${service_name}_secrets_${TIMESTAMP}.json" "$image"
    
    echo "✅ Scan complete for $service_name"
    echo "   Reports saved in reports/ directory"
    echo ""
}

# Function to get running images from Kubernetes
get_k8s_images() {
    echo "🔍 Finding images in microservices namespace..."
    kubectl get pods -n microservices -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq
}

echo "Starting comprehensive security scanning..."
echo ""

# Scan specific microservice images
echo "🎯 Scanning Microservices Images:"
echo "================================"

# Define your microservice images
IMAGES=(
    "node:18-alpine"
    "nginx:alpine"
    "mongo:latest"
)

# Get actual images from running pods
if command -v kubectl &> /dev/null; then
    echo "📋 Getting images from running pods..."
    RUNNING_IMAGES=($(get_k8s_images))
    
    for image in "${RUNNING_IMAGES[@]}"; do
        if [[ ! "$image" =~ ^(k8s\.gcr\.io|gcr\.io/distroless) ]]; then
            service_name=$(echo "$image" | sed 's|.*/||' | sed 's|:.*||')
            scan_image "$image" "$service_name"
        fi
    done
else
    echo "⚠️  kubectl not found. Scanning predefined images..."
    for image in "${IMAGES[@]}"; do
        service_name=$(echo "$image" | sed 's|:.*||')
        scan_image "$image" "$service_name"
    done
fi

# Scan local Docker images if Docker is available
if command -v docker &> /dev/null; then
    echo "🐳 Scanning Local Docker Images:"
    echo "==============================="
    
    # Get locally built images
    LOCAL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(api-gateway|order-service|auth-service|frontend|product-service)" | head -10)
    
    for image in $LOCAL_IMAGES; do
        service_name=$(echo "$image" | sed 's|:.*||')
        scan_image "$image" "$service_name"
    done
fi

# Generate summary report
echo "📊 Generating Summary Report..."
echo "=============================="

cat > "reports/scan_summary_${TIMESTAMP}.txt" << EOF
Trivy Security Scan Summary
==========================
Scan Date: $(date)
Timestamp: ${TIMESTAMP}

Scanned Images:
EOF

if [[ ${#RUNNING_IMAGES[@]} -gt 0 ]]; then
    printf '%s\n' "${RUNNING_IMAGES[@]}" >> "reports/scan_summary_${TIMESTAMP}.txt"
else
    printf '%s\n' "${IMAGES[@]}" >> "reports/scan_summary_${TIMESTAMP}.txt"
fi

cat >> "reports/scan_summary_${TIMESTAMP}.txt" << EOF

Report Files Generated:
$(ls -la reports/*${TIMESTAMP}*)

Critical Vulnerabilities Summary:
$(find reports -name "*vulnerabilities*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL") | .VulnerabilityID' {} \; 2>/dev/null | sort | uniq -c | sort -nr | head -10)

High Vulnerabilities Summary:
$(find reports -name "*vulnerabilities*${TIMESTAMP}.json" -exec jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH") | .VulnerabilityID' {} \; 2>/dev/null | sort | uniq -c | sort -nr | head -10)
EOF

echo ""
echo "✅ Security scanning complete!"
echo "📁 Reports saved in: ./reports/"
echo "📄 Summary report: reports/scan_summary_${TIMESTAMP}.txt"
echo ""
echo "🔍 To view critical vulnerabilities:"
echo "   cat reports/scan_summary_${TIMESTAMP}.txt"
echo ""
echo "🔍 To view detailed reports:"
echo "   cat reports/*_vulnerabilities_${TIMESTAMP}.txt"
