@echo off
echo =====================================
echo    Enhanced AKAS v2.0 Test Launch
echo =====================================
echo.
echo Checking environment setup...
if not exist .env (
    echo Warning: .env file not found!
    echo Copy .env.example to .env and configure your API keys
    echo.
)

echo Stopping current services...
docker-compose down

echo.
echo Starting Enhanced AKAS Services...
echo - Backend: enhanced_main.py (Port 8000)
echo - Frontend: enhanced_app.py (Port 8501)
echo - MongoDB: Optional persistence (Port 27017)
echo - Redis: Optional caching (Port 6379)
echo - Qdrant: Optional vector DB (Port 6333)
echo.

docker-compose -f docker-compose-test-enhanced.yml up --build

echo.
echo =====================================
echo    Enhanced AKAS URLs
echo =====================================
echo Frontend:     http://localhost:8501
echo Backend API:  http://localhost:8000
echo API Docs:     http://localhost:8000/docs
echo Health Check: http://localhost:8000/health
echo MongoDB:      http://localhost:27017 (admin/password123)
echo Qdrant:       http://localhost:6333
echo =====================================
echo.
echo Login credentials: admin / admin123
echo.
pause
