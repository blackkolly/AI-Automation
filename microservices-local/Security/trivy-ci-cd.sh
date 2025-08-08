#!/bin/bash

# Trivy CI/CD Pipeline Integration Script
echo "🚀 Trivy CI/CD Integration"
echo "=========================="

# Create CI/CD templates directory
mkdir -p ci-cd-templates

# Function to create GitHub Actions workflow
create_github_actions() {
    cat > "ci-cd-templates/trivy-security-scan.yml" << 'EOF'
name: Security Scan with Trivy

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC

jobs:
  trivy-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'
        
    - name: Run Trivy for container images
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'node:18-alpine'
        format: 'table'
        exit-code: '1'
        severity: 'CRITICAL,HIGH'
        
  kubernetes-scan:
    name: Kubernetes Security Scan
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
      
    - name: Run Trivy K8s scan
      run: |
        trivy k8s --report summary cluster
        
    - name: Upload K8s scan results
      uses: actions/upload-artifact@v3
      with:
        name: k8s-security-report
        path: trivy-k8s-report.json
EOF

    echo "✅ GitHub Actions workflow created: ci-cd-templates/trivy-security-scan.yml"
}

# Function to create Jenkins pipeline
create_jenkins_pipeline() {
    cat > "ci-cd-templates/Jenkinsfile-trivy" << 'EOF'
pipeline {
    agent any
    
    environment {
        TRIVY_VERSION = '0.58.1'
    }
    
    stages {
        stage('Install Trivy') {
            steps {
                script {
                    sh '''
                        if ! command -v trivy &> /dev/null; then
                            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
                            sudo apt-get update
                            sudo apt-get install trivy
                        fi
                    '''
                }
            }
        }
        
        stage('Filesystem Scan') {
            steps {
                sh 'trivy fs --format json --output trivy-fs-report.json .'
                sh 'trivy fs --format table .'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('Container Image Scan') {
            steps {
                script {
                    def images = ['node:18-alpine', 'nginx:alpine', 'mongo:latest']
                    for (image in images) {
                        sh "trivy image --format json --output trivy-${image.replace(':', '-')}.json ${image}"
                        sh "trivy image --exit-code 1 --severity CRITICAL,HIGH ${image}"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('Kubernetes Scan') {
            when {
                branch 'main'
            }
            steps {
                sh 'trivy k8s --report summary --format json --output trivy-k8s-report.json cluster'
                sh 'trivy k8s --report summary cluster'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-k8s-report.json', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: '.',
                reportFiles: 'trivy-*.json',
                reportName: 'Trivy Security Report'
            ])
        }
        failure {
            emailext (
                subject: "Security Scan Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The Trivy security scan has detected critical vulnerabilities. Please check the build logs.",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
EOF

    echo "✅ Jenkins pipeline created: ci-cd-templates/Jenkinsfile-trivy"
}

# Function to create GitLab CI configuration
create_gitlab_ci() {
    cat > "ci-cd-templates/.gitlab-ci.yml" << 'EOF'
stages:
  - security-scan
  - deploy

variables:
  TRIVY_VERSION: "0.58.1"

trivy-container-scan:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    - trivy fs --format json --output trivy-fs-report.json .
    - trivy fs --exit-code 1 --severity CRITICAL,HIGH .
  artifacts:
    reports:
      container_scanning: trivy-fs-report.json
    paths:
      - trivy-fs-report.json
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH
    - if: $CI_MERGE_REQUEST_ID

trivy-image-scan:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    - trivy image --format json --output trivy-image-report.json node:18-alpine
    - trivy image --exit-code 1 --severity CRITICAL,HIGH node:18-alpine
  artifacts:
    reports:
      container_scanning: trivy-image-report.json
    paths:
      - trivy-image-report.json
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

trivy-k8s-scan:
  stage: security-scan
  image: aquasec/trivy:latest
  script:
    - trivy k8s --report summary --format json --output trivy-k8s-report.json cluster
  artifacts:
    paths:
      - trivy-k8s-report.json
    expire_in: 1 week
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  only:
    variables:
      - $K8S_SCANNING_ENABLED == "true"
EOF

    echo "✅ GitLab CI configuration created: ci-cd-templates/.gitlab-ci.yml"
}

# Function to create Docker Compose for local development
create_docker_compose() {
    cat > "ci-cd-templates/docker-compose-trivy.yml" << 'EOF'
version: '3.8'

services:
  trivy-server:
    image: aquasec/trivy:latest
    command: ["server", "--listen", "0.0.0.0:4954"]
    ports:
      - "4954:4954"
    volumes:
      - trivy_cache:/root/.cache/trivy
    environment:
      - TRIVY_DEBUG=true
    networks:
      - security-network

  trivy-scanner:
    image: aquasec/trivy:latest
    depends_on:
      - trivy-server
    volumes:
      - ./:/workspace
      - trivy_cache:/root/.cache/trivy
    working_dir: /workspace
    networks:
      - security-network
    command: >
      sh -c "
        sleep 10 &&
        trivy fs --server http://trivy-server:4954 --format json --output /workspace/reports/trivy-local-scan.json . &&
        trivy image --server http://trivy-server:4954 --format table node:18-alpine
      "

volumes:
  trivy_cache:

networks:
  security-network:
    driver: bridge
EOF

    echo "✅ Docker Compose for Trivy created: ci-cd-templates/docker-compose-trivy.yml"
}

# Function to create Helm chart for Trivy operator
create_helm_chart() {
    mkdir -p helm-charts/trivy-operator
    
    cat > "helm-charts/trivy-operator/Chart.yaml" << 'EOF'
apiVersion: v2
name: trivy-operator
description: Trivy Operator for Kubernetes Security Scanning
type: application
version: 0.1.0
appVersion: "0.22.0"
dependencies:
  - name: trivy-operator
    version: 0.22.0
    repository: https://aquasecurity.github.io/helm-charts/
EOF

    cat > "helm-charts/trivy-operator/values.yaml" << 'EOF'
trivy-operator:
  serviceMonitor:
    enabled: true
  trivy:
    storageClassName: "standard"
  operator:
    vulnerabilityScannerEnabled: true
    configAuditScannerEnabled: true
    exposedSecretScannerEnabled: true
    rbacAssessmentScannerEnabled: true
EOF

    echo "✅ Helm chart for Trivy Operator created: helm-charts/trivy-operator/"
}

# Main execution
echo "Creating CI/CD integration templates..."
echo ""

create_github_actions
create_jenkins_pipeline  
create_gitlab_ci
create_docker_compose
create_helm_chart

echo ""
echo "🎯 CI/CD Integration Summary:"
echo "============================"
echo "✅ GitHub Actions workflow: ci-cd-templates/trivy-security-scan.yml"
echo "✅ Jenkins pipeline: ci-cd-templates/Jenkinsfile-trivy"
echo "✅ GitLab CI configuration: ci-cd-templates/.gitlab-ci.yml"
echo "✅ Docker Compose: ci-cd-templates/docker-compose-trivy.yml"
echo "✅ Helm chart: helm-charts/trivy-operator/"
echo ""
echo "📝 Integration Instructions:"
echo "==========================="
echo "1. GitHub: Copy trivy-security-scan.yml to .github/workflows/"
echo "2. Jenkins: Use Jenkinsfile-trivy in your pipeline"
echo "3. GitLab: Copy .gitlab-ci.yml to your repository root"
echo "4. Local Dev: Run 'docker-compose -f docker-compose-trivy.yml up'"
echo "5. K8s Operator: Deploy with 'helm install trivy-operator ./helm-charts/trivy-operator'"
echo ""
echo "🚀 CI/CD Integration templates created successfully!"
