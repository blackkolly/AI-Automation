@echo off
echo 🚀 AKAS v2.0 Simple Launch (OpenAI Only)
echo ==========================================

echo 📛 Stopping existing containers...
docker-compose down

echo 🔨 Building enhanced backend and frontend...
docker-compose build

echo 🚀 Starting enhanced AKAS v2.0...
docker-compose up -d

echo ⏳ Waiting for services to start...
timeout /t 15 /nobreak > nul

echo 🔍 Checking system health...
curl -f http://localhost:8000/v2/health/ || echo ❌ Backend not ready yet, give it a few more seconds

echo.
echo ✅ AKAS v2.0 launched successfully!
echo.
echo 🌐 Access your system:
echo    Enhanced Frontend: http://localhost:8501
echo    Backend API: http://localhost:8000
echo    API Documentation: http://localhost:8000/docs
echo    n8n Workflow: http://localhost:5678
echo.
echo 🤖 Available Features:
echo    ✅ OpenAI integration (GPT models)
echo    ✅ Multi-file document upload
echo    ✅ Advanced query interface
echo    ✅ Real-time analytics
echo    ✅ System health monitoring
echo    ✅ User feedback system
echo    🟡 Google API (if key provided)
echo    ❌ Anthropic (requires API key)
echo.
echo 💡 To add more LLM providers:
echo    1. Get API keys for Anthropic/Google
echo    2. Update your .env files
echo    3. Restart the system
echo.
pause
