#!/bin/bash

# 🔍 Jaeger Distributed Tracing Demo Script

echo "🚀 Starting Jaeger Distributed Tracing Demonstration"
echo "=================================================="

# Check if Jaeger is accessible
echo "🔍 Testing Jaeger UI accessibility..."
JAEGER_URL="http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686"

curl -s -o /dev/null -w "%{http_code}" "$JAEGER_URL" | grep -q "200" && \
  echo "✅ Jaeger UI is accessible at: $JAEGER_URL" || \
  echo "❌ Jaeger UI is not accessible"

echo ""
echo "🎯 Demo Scenarios for Distributed Tracing"
echo "========================================="

echo ""
echo "📋 Scenario 1: Simple Order Creation Flow"
echo "------------------------------------------"
echo "This will demonstrate a trace spanning multiple services:"
echo "  User Request → API Gateway → Order Service → Database → Kafka"

# Test your API Gateway endpoint (replace with your actual endpoint)
API_GATEWAY_URL="http://your-api-gateway-url"

echo ""
echo "🔄 Making test request to create an order..."

# Create a sample order request
curl -X POST "$API_GATEWAY_URL/api/orders" \
  -H "Content-Type: application/json" \
  -H "User-ID: demo-user-123" \
  -H "Request-ID: demo-trace-$(date +%s)" \
  -d '{
    "userId": "demo-user-123",
    "items": [
      {
        "productId": "laptop-pro-15",
        "quantity": 1,
        "price": 1299.99
      },
      {
        "productId": "wireless-mouse",
        "quantity": 2,
        "price": 29.99
      }
    ],
    "totalAmount": 1359.97,
    "customerTier": "premium",
    "shippingMethod": "express"
  }' 2>/dev/null && echo "✅ Order request sent successfully" || echo "❌ Order request failed"

echo ""
echo "📋 Scenario 2: Error Handling Demonstration"
echo "---------------------------------------------"
echo "This will show how errors are traced across services:"

# Send a request that will likely cause an error
curl -X POST "$API_GATEWAY_URL/api/orders" \
  -H "Content-Type: application/json" \
  -H "User-ID: error-demo-user" \
  -d '{
    "userId": "",
    "items": [],
    "totalAmount": -100
  }' 2>/dev/null && echo "✅ Error scenario request sent" || echo "❌ Error scenario request failed"

echo ""
echo "📋 Scenario 3: Performance Testing"
echo "-----------------------------------"
echo "Sending multiple concurrent requests to demonstrate load tracing:"

for i in {1..5}; do
  curl -X GET "$API_GATEWAY_URL/api/users/user-$i" \
    -H "User-ID: perf-test-$i" \
    -H "Request-ID: perf-$(date +%s)-$i" &
done

wait
echo "✅ Performance test requests completed"

echo ""
echo "🎯 Viewing Traces in Jaeger UI"
echo "==============================="
echo ""
echo "1. Open Jaeger UI: $JAEGER_URL"
echo ""
echo "2. Select a service from the dropdown:"
echo "   - api-gateway (entry point)"
echo "   - order-service (business logic)"
echo "   - user-service (user data)"
echo "   - inventory-service (stock management)"
echo ""
echo "3. Set time range: Last 15 minutes"
echo ""
echo "4. Click 'Find Traces' to see all traces"
echo ""
echo "🔍 What to Look For:"
echo "==================="
echo ""
echo "📊 Service Map:"
echo "   - Visual representation of service dependencies"
echo "   - Request flow between services"
echo "   - Error rates and performance metrics"
echo ""
echo "📈 Trace Timeline:"
echo "   - Chronological view of request processing"
echo "   - Span duration and overlap"
echo "   - Bottlenecks and slow operations"
echo ""
echo "🏷️ Span Tags and Logs:"
echo "   - HTTP methods and status codes"
echo "   - Database queries and execution times"
echo "   - Custom business logic tags"
echo "   - Error messages and stack traces"
echo ""
echo "⚡ Performance Insights:"
echo "   - Total request duration"
echo "   - Service-specific processing time"
echo "   - Database query performance"
echo "   - Network latency between services"
echo ""
echo "🚨 Error Analysis:"
echo "   - Failed spans highlighted in red"
echo "   - Error logs and stack traces"
echo "   - Error propagation across services"
echo ""

echo "🎓 Understanding Trace Structure:"
echo "================================="
echo ""
echo "Root Span (API Gateway):"
echo "├── HTTP Request Processing"
echo "├── Authentication/Authorization"
echo "├── Child Span (Order Service Call)"
echo "│   ├── Input Validation"
echo "│   ├── Database Insert"
echo "│   ├── Kafka Message Publish"
echo "│   └── Response Preparation"
echo "├── Child Span (User Service Call)"
echo "│   ├── User Data Retrieval"
echo "│   └── User Validation"
echo "└── Response Generation"
echo ""

echo "💡 Jaeger Search Tips:"
echo "======================"
echo ""
echo "🔍 Search by Service:"
echo "   - Service: 'order-service'"
echo "   - Operation: 'POST /orders'"
echo ""
echo "🔍 Search by Tags:"
echo "   - user.id='demo-user-123'"
echo "   - http.status_code='500'"
echo "   - error='true'"
echo ""
echo "🔍 Search by Duration:"
echo "   - Min Duration: 100ms (slow requests)"
echo "   - Max Duration: 1s (timeout analysis)"
echo ""
echo "🔍 Search by Time:"
echo "   - Lookback: 1h (recent activity)"
echo "   - Custom range for specific incidents"
echo ""

echo "📚 Advanced Jaeger Features:"
echo "============================="
echo ""
echo "🔄 Trace Comparison:"
echo "   - Compare successful vs failed requests"
echo "   - Identify performance differences"
echo ""
echo "📊 Service Performance:"
echo "   - Average response times per service"
echo "   - Error rates and trends"
echo "   - Dependency analysis"
echo ""
echo "🎯 Dependency Graph:"
echo "   - Service interaction visualization"
echo "   - Critical path identification"
echo "   - Bottleneck analysis"
echo ""

echo ""
echo "🎉 Demo Complete!"
echo "================="
echo ""
echo "Next Steps:"
echo "1. Explore traces in Jaeger UI: $JAEGER_URL"
echo "2. Try different search filters and time ranges"
echo "3. Analyze service dependencies and performance"
echo "4. Use traces to debug issues and optimize performance"
echo ""
echo "📖 Additional Resources:"
echo "- Full Integration Guide: ./JAEGER_INTEGRATION_GUIDE.md"
echo "- Quick Setup Instructions: ./QUICK_JAEGER_SETUP.md"
echo "- Jaeger Documentation: https://www.jaegertracing.io/docs/"
echo ""
echo "Happy Tracing! 🔍✨"
