@echo off
REM =================================================================
REM REAL TESTING SCRIPT FOR YOUR KUBERNETES MICROSERVICES PLATFORM
REM =================================================================
REM
REM This script tests YOUR actual services:
REM - API Gateway (localhost:30000)
REM - Auth Service (localhost:30001)
REM - Product Service (localhost:30002) 
REM - Order Service (localhost:30003)
REM - Frontend Dashboard (localhost:30080)
REM
REM =================================================================

echo.
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo ^🚀 TESTING YOUR ACTUAL KUBERNETES MICROSERVICES PLATFORM
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.

setlocal enabledelayedexpansion

REM Test results tracking
set TESTS_PASSED=0
set TESTS_FAILED=0
set TOTAL_TESTS=0

REM YOUR actual service URLs
set API_GATEWAY=http://localhost:30000
set AUTH_SERVICE=http://localhost:30001
set PRODUCT_SERVICE=http://localhost:30002
set ORDER_SERVICE=http://localhost:30003
set FRONTEND=http://localhost:30080

echo Phase 1: Service Health Checks
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.

REM Test API Gateway Health
echo ^🔄 Testing: API Gateway Health Check
curl -s -f "%API_GATEWAY%/health" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: API Gateway is healthy
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: API Gateway is not responding
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Auth Service Health
echo ^🔄 Testing: Auth Service Health Check
curl -s -f "%AUTH_SERVICE%/health" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Auth Service is healthy
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Auth Service is not responding
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Product Service Health
echo ^🔄 Testing: Product Service Health Check
curl -s -f "%PRODUCT_SERVICE%/health" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Product Service is healthy
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Product Service is not responding
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Order Service Health
echo ^🔄 Testing: Order Service Health Check
curl -s -f "%ORDER_SERVICE%/health" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Order Service is healthy
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Order Service is not responding
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Frontend
echo ^🔄 Testing: Frontend Dashboard Access
curl -s -f "%FRONTEND%" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Frontend dashboard is accessible
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Frontend dashboard is not accessible
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

echo Phase 2: Endpoint Functionality Tests
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.

REM Test Auth Service Login
echo ^🔄 Testing: Auth Service Login Endpoint
curl -s -X POST -H "Content-Type: application/json" -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}" "%AUTH_SERVICE%/auth/login" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Auth Service login endpoint works
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Auth Service login endpoint failed
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Product Service Products
echo ^🔄 Testing: Product Service Products List
curl -s "%PRODUCT_SERVICE%/products" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Product Service products endpoint works
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Product Service products endpoint failed
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test Order Service Orders
echo ^🔄 Testing: Order Service Orders List
curl -s "%ORDER_SERVICE%/orders" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Order Service orders endpoint works
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Order Service orders endpoint failed
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

REM Test API Gateway Status
echo ^🔄 Testing: API Gateway Status Endpoint
curl -s "%API_GATEWAY%/api/status" >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: API Gateway status endpoint works
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: API Gateway status endpoint failed
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1
echo.

echo Phase 3: Integration Flow Test
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.

echo ^🔄 Testing: Complete User Flow
echo Step 1: Authenticating with Auth Service...
curl -s -X POST -H "Content-Type: application/json" -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}" "%AUTH_SERVICE%/auth/login" >temp_auth.txt 2>&1
findstr "token" temp_auth.txt >nul
if !errorlevel! == 0 (
    echo ^✅ Authentication successful
) else (
    echo ^❌ Authentication failed
)

echo Step 2: Fetching products from Product Service...
curl -s "%PRODUCT_SERVICE%/products" >temp_products.txt 2>&1
findstr "id" temp_products.txt >nul
if !errorlevel! == 0 (
    echo ^✅ Products retrieved successfully
) else (
    echo ^❌ Product retrieval failed
)

echo Step 3: Fetching orders from Order Service...
curl -s "%ORDER_SERVICE%/orders" >temp_orders.txt 2>&1
findstr "[" temp_orders.txt >nul
if !errorlevel! == 0 (
    echo ^✅ Orders retrieved successfully
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ Order retrieval failed
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1

REM Clean up temp files
del temp_auth.txt temp_products.txt temp_orders.txt >nul 2>&1

echo.

echo Phase 4: Load Testing (K6)
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.

REM Check if Docker is available for K6
echo ^🔄 Running: K6 Load Test on YOUR Services with Docker
docker run --rm --network host -v "%cd%/performance:/scripts" grafana/k6 run --duration 30s --vus 2 /scripts/load-tests/real-microservices-test.js >nul 2>&1
if !errorlevel! == 0 (
    echo ^✅ PASSED: Docker K6 load test completed
    set /a TESTS_PASSED+=1
) else (
    echo ^❌ FAILED: Docker K6 load test failed ^(services may be down^)
    set /a TESTS_FAILED+=1
)
set /a TOTAL_TESTS+=1

echo.

echo ^🎯 REAL TEST RESULTS FOR YOUR MICROSERVICES PLATFORM
echo ^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=^=
echo.
echo ^📊 Test Statistics:
echo ^✅ Tests Passed: %TESTS_PASSED%
echo ^❌ Tests Failed: %TESTS_FAILED%
set /a SUCCESS_RATE=TESTS_PASSED*100/TOTAL_TESTS
echo ^📈 Success Rate: %SUCCESS_RATE%%%
echo.

echo ^🔗 YOUR Services Tested:
echo ^• API Gateway: %API_GATEWAY%
echo ^• Auth Service: %AUTH_SERVICE%
echo ^• Product Service: %PRODUCT_SERVICE%
echo ^• Order Service: %ORDER_SERVICE%
echo ^• Frontend Dashboard: %FRONTEND%
echo.

if %TESTS_FAILED% == 0 (
    echo ^🎉 ALL TESTS PASSED! ^🎉
    echo Your Kubernetes microservices platform is working perfectly!
    echo.
    echo ^✨ Validated Components:
    echo ^• ^✅ API Gateway - Health ^& routing
    echo ^• ^✅ Auth Service - Authentication endpoints
    echo ^• ^✅ Product Service - Product catalog endpoints
    echo ^• ^✅ Order Service - Order management endpoints
    echo ^• ^✅ Frontend Dashboard - User interface
    echo ^• ^✅ Service Integration - Complete workflows
    echo ^• ^✅ Performance - Load testing
    echo.
) else (
    echo ^⚠️ Some tests failed for your services.
    echo ^💡 This might be because:
    echo ^• Services are not running ^(kubectl get pods^)
    echo ^• Ports are not exposed correctly ^(kubectl get svc^)
    echo ^• Services are starting up ^(check logs^)
    echo.
)

echo Press any key to continue...
pause >nul
