#!/bin/bash

echo "🧪 Testing n8n Integration Visibility"
echo "======================================"

# Start services
echo "Starting services..."
docker-compose -f docker-compose-test-enhanced.yml up -d

# Wait for startup
echo "Waiting for services to start..."
sleep 20

echo ""
echo "🔍 TESTING n8n INTEGRATION VISIBILITY:"
echo ""

# Test 1: Check if n8n status shows in health endpoint
echo "1️⃣  Testing health endpoint for n8n status..."
echo "URL: http://localhost:8000/v2/health/"
curl -s http://localhost:8000/v2/health/ | jq '.n8n_status, .n8n_enabled' 2>/dev/null || echo "❌ Health check failed"

echo ""

# Test 2: Check n8n status endpoint
echo "2️⃣  Testing n8n status endpoint..."
echo "URL: http://localhost:8000/v2/n8n-status/"
curl -s http://localhost:8000/v2/n8n-status/ | jq . 2>/dev/null || echo "❌ n8n status failed"

echo ""

# Test 3: Upload a document and check for n8n workflow response
echo "3️⃣  Testing document upload with n8n workflow trigger..."
echo "Creating test file..."
echo "This is a test document for n8n integration demo." > test_doc.txt

echo "Uploading document..."
response=$(curl -s -X POST "http://localhost:8000/v2/ingest/" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "files=@test_doc.txt")

echo "Upload response:"
echo "$response" | jq . 2>/dev/null || echo "$response"

# Check if n8n_workflow field exists in response
if echo "$response" | grep -q "n8n_workflow"; then
    echo "✅ n8n workflow field found in response!"
else
    echo "❌ n8n workflow field NOT found in response"
fi

echo ""

# Test 4: Make a query and check for n8n workflow trigger
echo "4️⃣  Testing query with n8n workflow trigger..."
query_response=$(curl -s -X POST "http://localhost:8000/v2/query/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"question": "What is this document about?", "llm_provider": "openai"}')

echo "Query response:"
echo "$query_response" | jq . 2>/dev/null || echo "$query_response"

echo ""

# Test 5: Manual workflow trigger
echo "5️⃣  Testing manual workflow trigger..."
trigger_response=$(curl -s -X POST "http://localhost:8000/v2/trigger-workflow/?workflow_name=test-demo" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"demo": true, "timestamp": "'$(date)'"}')

echo "Manual trigger response:"
echo "$trigger_response" | jq . 2>/dev/null || echo "$trigger_response"

echo ""
echo "🌐 ACCESS POINTS:"
echo "Frontend: http://localhost:8501 (check for n8n Workflows tab)"
echo "n8n UI: http://localhost:5678 (admin/password)"
echo "API Docs: http://localhost:8000/docs"

echo ""
echo "Press Enter to cleanup and stop services..."
read
rm -f test_doc.txt
docker-compose -f docker-compose-test-enhanced.yml down
