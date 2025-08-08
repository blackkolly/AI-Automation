#!/bin/bash

echo "🚀 AKAS v2.0 Implementation Script"
echo "=================================="

# Stop existing containers
echo "📛 Stopping existing containers..."
docker-compose down

# Build new images
echo "🔨 Building enhanced backend and frontend..."
docker-compose build --no-cache

# Start the enhanced system
echo "🚀 Starting enhanced AKAS v2.0..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 10

# Check health
echo "🔍 Checking system health..."
curl -f http://localhost:8000/v2/health/ || echo "❌ Backend health check failed"

echo "✅ AKAS v2.0 implementation complete!"
echo ""
echo "🌐 Access your enhanced system:"
echo "   Frontend: http://localhost:8501"
echo "   Backend API: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo "   n8n: http://localhost:5678"
echo ""
echo "🆕 New features available:"
echo "   - Enhanced multi-file upload"
echo "   - Advanced query interface"
echo "   - Real-time analytics"
echo "   - System health monitoring"
echo "   - User feedback system"
echo "   - Backward compatibility with v1 API"
