#!/bin/bash

echo ""
echo "================================================="
echo "   AKAS n8n Integration Demonstration"
echo "================================================="
echo ""

echo "Starting Enhanced AKAS with n8n integration..."
docker-compose -f docker-compose-test-enhanced.yml up -d

echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "================================================="
echo "   TEST THE INTEGRATION:"
echo "================================================="
echo ""
echo "1. Frontend (with n8n tab):     http://localhost:8501"
echo "2. n8n Interface:               http://localhost:5678 (admin/password)"
echo "3. API Docs:                    http://localhost:8000/docs"
echo "4. n8n Status API:              http://localhost:8000/v2/n8n-status/"
echo "5. Health Check (with n8n):     http://localhost:8000/v2/health/"
echo ""
echo "================================================="
echo "   VISIBLE DIFFERENCES WITH n8n:"
echo "================================================="
echo ""
echo "WITHOUT n8n:"
echo "  - No workflow tab in frontend"
echo "  - Upload returns only: {\"results\": [...]}"
echo "  - No automation capabilities"
echo ""
echo "WITH n8n:"
echo "  - Dedicated \"n8n Workflows\" tab"
echo "  - Upload returns: {\"results\": [...], \"n8n_workflow\": {...}}"
echo "  - Real-time workflow status in sidebar"
echo "  - Manual workflow testing"
echo "  - External system integration"
echo ""

# Function to check if services are ready
check_services() {
    echo "Checking service health..."
    
    # Check backend
    if curl -s http://localhost:8000/v2/health/ > /dev/null 2>&1; then
        echo "✅ Backend: Ready"
    else
        echo "❌ Backend: Not ready"
    fi
    
    # Check frontend
    if curl -s http://localhost:8501 > /dev/null 2>&1; then
        echo "✅ Frontend: Ready"
    else
        echo "❌ Frontend: Not ready"
    fi
    
    # Check n8n
    if curl -s http://localhost:5678 > /dev/null 2>&1; then
        echo "✅ n8n: Ready"
    else
        echo "❌ n8n: Not ready"
    fi
    
    echo ""
}

# Check if curl is available
if command -v curl &> /dev/null; then
    check_services
fi

echo "================================================="
echo "   QUICK TESTS:"
echo "================================================="
echo ""
echo "Test backend health (includes n8n status):"
echo "curl http://localhost:8000/v2/health/"
echo ""
echo "Test n8n status:"
echo "curl http://localhost:8000/v2/n8n-status/"
echo ""
echo "Manual workflow trigger example:"
echo "curl -X POST \"http://localhost:8000/v2/trigger-workflow/?workflow_name=test\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"test\": true}'"
echo ""

echo "Press Enter to stop the demo..."
read -r

echo ""
echo "Stopping services..."
docker-compose -f docker-compose-test-enhanced.yml down

echo ""
echo "Demo completed!"
echo ""
