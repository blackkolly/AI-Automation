#!/bin/bash

echo "🔄 AKAS: With vs Without n8n Comparison"
echo "======================================="

# Function to test without n8n
test_without_n8n() {
    echo ""
    echo "🚫 TESTING WITHOUT n8n (V2 Version):"
    echo "-----------------------------------"
    
    # Start V2 version (without n8n integration)
    docker-compose up -d
    sleep 15
    
    echo "Creating test document..."
    echo "Test document without n8n" > test_no_n8n.txt
    
    echo "Uploading document (no n8n)..."
    response_no_n8n=$(curl -s -X POST "http://localhost:8000/v2/ingest/" \
      -H "Content-Type: multipart/form-data" \
      -F "files=@test_no_n8n.txt")
    
    echo "Response WITHOUT n8n:"
    echo "$response_no_n8n" | jq . 2>/dev/null || echo "$response_no_n8n"
    
    # Check for n8n fields
    if echo "$response_no_n8n" | grep -q "n8n_workflow"; then
        echo "❌ Unexpected: n8n field found in non-n8n version"
    else
        echo "✅ Correct: No n8n fields in response"
    fi
    
    echo ""
    echo "Health check WITHOUT n8n:"
    curl -s http://localhost:8000/v2/health/ | jq 'select(.n8n_status)' 2>/dev/null || echo "No n8n status (expected)"
    
    docker-compose down
    rm -f test_no_n8n.txt
}

# Function to test with n8n
test_with_n8n() {
    echo ""
    echo "✅ TESTING WITH n8n (Enhanced Version):"
    echo "--------------------------------------"
    
    # Start enhanced version (with n8n integration)
    docker-compose -f docker-compose-test-enhanced.yml up -d
    sleep 20
    
    echo "Creating test document..."
    echo "Test document with n8n integration" > test_with_n8n.txt
    
    echo "Uploading document (with n8n)..."
    response_with_n8n=$(curl -s -X POST "http://localhost:8000/v2/ingest/" \
      -H "Content-Type: multipart/form-data" \
      -F "files=@test_with_n8n.txt")
    
    echo "Response WITH n8n:"
    echo "$response_with_n8n" | jq . 2>/dev/null || echo "$response_with_n8n"
    
    # Check for n8n fields
    if echo "$response_with_n8n" | grep -q "n8n_workflow"; then
        echo "✅ Correct: n8n_workflow field found!"
    else
        echo "❌ Problem: n8n_workflow field missing"
    fi
    
    echo ""
    echo "Health check WITH n8n:"
    curl -s http://localhost:8000/v2/health/ | jq '.n8n_status, .n8n_enabled' 2>/dev/null || echo "n8n status check failed"
    
    echo ""
    echo "n8n Status endpoint:"
    curl -s http://localhost:8000/v2/n8n-status/ | jq . 2>/dev/null || echo "n8n status endpoint failed"
    
    docker-compose -f docker-compose-test-enhanced.yml down
    rm -f test_with_n8n.txt
}

# Run comparison
echo "This script will demonstrate the clear difference between"
echo "AKAS with and without n8n integration."
echo ""
echo "Press Enter to start comparison..."
read

test_without_n8n
test_with_n8n

echo ""
echo "🎯 SUMMARY OF DIFFERENCES:"
echo "========================="
echo ""
echo "WITHOUT n8n:"
echo "  ❌ No n8n_workflow field in responses"
echo "  ❌ No n8n status in health checks"
echo "  ❌ No workflow automation"
echo "  ❌ No n8n management interface"
echo ""
echo "WITH n8n:"
echo "  ✅ n8n_workflow field in upload responses"
echo "  ✅ n8n status in health checks"  
echo "  ✅ Workflow automation triggers"
echo "  ✅ n8n management tab in frontend"
echo "  ✅ Manual workflow testing"
echo ""
echo "To see full integration:"
echo "1. Run: ./test_n8n_visibility.sh"
echo "2. Visit: http://localhost:8501 (check for n8n Workflows tab)"
echo "3. Visit: http://localhost:5678 (n8n interface)"
