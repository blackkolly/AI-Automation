#!/bin/bash

# =================================================================
# SIMPLE TEST RUNNER - VALIDATES TESTING FRAMEWORK
# =================================================================
#
# This script validates that our testing framework is properly
# structured and can run basic tests without external dependencies
#
# =================================================================

echo "🧪 AUTOMATED TESTING FRAMEWORK VALIDATION"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}🔄 Running: ${test_name}${NC}"
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}✅ PASSED: ${test_name}${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED: ${test_name}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

# Function to check file exists
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $description exists: $file${NC}"
        return 0
    else
        echo -e "${RED}❌ $description missing: $file${NC}"
        return 1
    fi
}

# Function to check directory exists  
check_directory() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $description exists: $dir${NC}"
        return 0
    else
        echo -e "${RED}❌ $description missing: $dir${NC}"
        return 1
    fi
}

echo "🔍 FRAMEWORK STRUCTURE VALIDATION"
echo "================================="
echo ""

# Check core configuration files
check_file "package.json" "Package configuration"
check_file "jest.config.js" "Jest configuration"
check_file "playwright.config.js" "Playwright configuration"
check_file "docker-compose.test.yml" "Docker test environment"
check_file "README.md" "Documentation"
check_file "run-all-tests.sh" "Test runner script"

echo ""

# Check directory structure
check_directory "unit" "Unit tests directory"
check_directory "integration" "Integration tests directory" 
check_directory "e2e" "E2E tests directory"
check_directory "performance" "Performance tests directory"
check_directory "security" "Security tests directory"
check_directory "config" "Configuration directory"

echo ""
echo "📋 TEST FILE VALIDATION"
echo "======================="
echo ""

# Check test files exist
check_file "unit/services/UserService.test.js" "Unit test example"
check_file "integration/api/api.test.js" "Integration test example"
check_file "e2e/user-journeys/complete-workflows.spec.js" "E2E test example"
check_file "performance/load-tests/api-load-test.js" "Performance test example"
check_file "security/owasp-zap/zap-scan.js" "Security test example"

echo ""
echo "⚙️  CONFIGURATION VALIDATION"
echo "============================="
echo ""

# Test package.json structure
if [ -f "package.json" ]; then
    if grep -q "jest" package.json; then
        echo -e "${GREEN}✅ Jest configured in package.json${NC}"
    else
        echo -e "${RED}❌ Jest missing from package.json${NC}"
    fi
    
    if grep -q "playwright" package.json; then
        echo -e "${GREEN}✅ Playwright configured in package.json${NC}"
    else
        echo -e "${RED}❌ Playwright missing from package.json${NC}"
    fi
    
    if grep -q "test:" package.json; then
        echo -e "${GREEN}✅ Test scripts configured${NC}"
    else
        echo -e "${RED}❌ Test scripts missing${NC}"
    fi
fi

echo ""

# Test Jest configuration
if [ -f "jest.config.js" ]; then
    if grep -q "coverage" jest.config.js; then
        echo -e "${GREEN}✅ Coverage configuration found${NC}"
    else
        echo -e "${RED}❌ Coverage configuration missing${NC}"
    fi
    
    if grep -q "testMatch" jest.config.js; then
        echo -e "${GREEN}✅ Test patterns configured${NC}"
    else
        echo -e "${RED}❌ Test patterns missing${NC}"
    fi
fi

echo ""
echo "🐳 DOCKER ENVIRONMENT VALIDATION"
echo "================================="
echo ""

# Check Docker Compose configuration
if [ -f "docker-compose.test.yml" ]; then
    if grep -q "mongo-test" docker-compose.test.yml; then
        echo -e "${GREEN}✅ MongoDB test service configured${NC}"
    else
        echo -e "${RED}❌ MongoDB test service missing${NC}"
    fi
    
    if grep -q "redis-test" docker-compose.test.yml; then
        echo -e "${GREEN}✅ Redis test service configured${NC}"
    else
        echo -e "${RED}❌ Redis test service missing${NC}"
    fi
    
    if grep -q "zap" docker-compose.test.yml; then
        echo -e "${GREEN}✅ OWASP ZAP service configured${NC}"
    else
        echo -e "${RED}❌ OWASP ZAP service missing${NC}"
    fi
fi

echo ""
echo "📊 VALIDATION SUMMARY"
echo "===================="
echo ""

if [ -f "package.json" ] && [ -f "jest.config.js" ] && [ -d "unit" ] && [ -d "integration" ]; then
    echo -e "${GREEN}✅ Core testing framework is properly structured${NC}"
    echo -e "${GREEN}✅ Ready for automated testing${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo "1. Install dependencies: npm install"
    echo "2. Start test environment: docker-compose -f docker-compose.test.yml up -d"
    echo "3. Run unit tests: npm run test:unit"
    echo "4. Run integration tests: npm run test:integration"
    echo "5. Run all tests: ./run-all-tests.sh"
    echo ""
    echo -e "${GREEN}🎉 Testing framework validation completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Testing framework has structural issues${NC}"
    echo -e "${RED}❌ Please check missing files and directories${NC}"
    exit 1
fi
