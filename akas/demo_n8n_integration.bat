@echo off
echo.
echo =================================================
echo   AKAS n8n Integration Demonstration
echo =================================================
echo.

echo Starting Enhanced AKAS with n8n integration...
docker-compose -f docker-compose-test-enhanced.yml up -d

echo.
echo Waiting for services to start...
timeout /t 10

echo.
echo =================================================
echo   TEST THE INTEGRATION:
echo =================================================
echo.
echo 1. Frontend (with n8n tab):     http://localhost:8501
echo 2. n8n Interface:               http://localhost:5678 (admin/password)
echo 3. API Docs:                    http://localhost:8000/docs
echo 4. n8n Status API:              http://localhost:8000/v2/n8n-status/
echo 5. Health Check (with n8n):     http://localhost:8000/v2/health/
echo.
echo =================================================
echo   VISIBLE DIFFERENCES WITH n8n:
echo =================================================
echo.
echo WITHOUT n8n:
echo   - No workflow tab in frontend
echo   - Upload returns only: {"results": [...]}
echo   - No automation capabilities
echo.
echo WITH n8n:
echo   - Dedicated "n8n Workflows" tab
echo   - Upload returns: {"results": [...], "n8n_workflow": {...}}
echo   - Real-time workflow status in sidebar
echo   - Manual workflow testing
echo   - External system integration
echo.
echo Press any key to stop the demo...
pause
docker-compose -f docker-compose-test-enhanced.yml down
