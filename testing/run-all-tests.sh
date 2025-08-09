#!/bin/bash

# =================================================================
# 🧪 COMPREHENSIVE TESTING FRAMEWORK - MASTER EXECUTION SCRIPT
# =================================================================
#
# This script orchestrates the complete testing pipeline including:
# - Unit Tests (Jest)
# - Integration Tests (Supertest + TestContainers)
# - End-to-End Tests (Playwright)
# - Performance Tests (K6)
# - Security Tests (OWASP ZAP)
#
# Usage:
#   ./run-all-tests.sh [--env=<environment>] [--type=<test-type>] [--parallel]
#
# Examples:
#   ./run-all-tests.sh                     # Run all tests
#   ./run-all-tests.sh --type=unit         # Run only unit tests
#   ./run-all-tests.sh --env=staging       # Run against staging environment
#   ./run-all-tests.sh --parallel          # Run tests in parallel where possible
#
# =================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$SCRIPT_DIR/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$REPORTS_DIR/test-execution-$TIMESTAMP.log"

# Default values
TEST_ENV="local"
TEST_TYPE="all"
PARALLEL_EXECUTION=false
FAIL_FAST=false
GENERATE_COVERAGE=true
SEND_NOTIFICATIONS=false

# Test execution flags
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_E2E=true
RUN_PERFORMANCE=true
RUN_SECURITY=true

# =================================================================
# UTILITY FUNCTIONS
# =================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "================================================================="
    echo "🧪 COMPREHENSIVE TESTING FRAMEWORK"
    echo "================================================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️ $1${NC}"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_tools+=("Node.js")
    else
        print_success "Node.js $(node --version)"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    else
        print_success "npm $(npm --version)"
    fi
    
    # Check Docker (for integration tests)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found - integration tests may fail"
    else
        print_success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    fi
    
    # Check K6 (for performance tests)
    if ! command -v k6 &> /dev/null && [ "$RUN_PERFORMANCE" = true ]; then
        print_warning "K6 not found - performance tests will be skipped"
        RUN_PERFORMANCE=false
    else
        print_success "K6 available"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install missing tools and try again"
        exit 1
    fi
}

setup_environment() {
    print_section "Setting Up Test Environment"
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_info "Installing dependencies..."
        npm install
    fi
    
    # Set environment variables
    export NODE_ENV=test
    export TEST_ENV="$TEST_ENV"
    export LOG_LEVEL=error
    export REPORTS_DIR="$REPORTS_DIR"
    export TIMESTAMP="$TIMESTAMP"
    
    # Environment-specific configuration
    case "$TEST_ENV" in
        "local")
            export BASE_URL="http://localhost:3000"
            export API_URL="http://localhost:3001"
            export DB_URL="mongodb://localhost:27017/test"
            ;;
        "staging")
            export BASE_URL="https://staging.example.com"
            export API_URL="https://api-staging.example.com"
            export DB_URL="$STAGING_DB_URL"
            ;;
        "production")
            export BASE_URL="https://example.com"
            export API_URL="https://api.example.com"
            export DB_URL="$PRODUCTION_DB_URL"
            ;;
    esac
    
    print_success "Environment configured for $TEST_ENV"
}

start_test_services() {
    print_section "Starting Test Services"
    
    if [ "$TEST_ENV" = "local" ]; then
        # Start local test services
        print_info "Starting test database containers..."
        docker-compose -f docker-compose.test.yml up -d
        
        # Wait for services to be ready
        print_info "Waiting for services to be ready..."
        ./scripts/wait-for-services.sh
        
        print_success "Test services started"
    else
        print_info "Using external services for $TEST_ENV environment"
    fi
}

run_unit_tests() {
    if [ "$RUN_UNIT" != true ]; then
        return 0
    fi
    
    print_section "Running Unit Tests"
    log_message "Starting unit tests"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Run Jest unit tests
    if npm run test:unit:ci; then
        print_success "Unit tests passed"
    else
        exit_code=$?
        print_error "Unit tests failed"
        if [ "$FAIL_FAST" = true ]; then
            return $exit_code
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_message "Unit tests completed in ${duration}s with exit code $exit_code"
    
    return $exit_code
}

run_integration_tests() {
    if [ "$RUN_INTEGRATION" != true ]; then
        return 0
    fi
    
    print_section "Running Integration Tests"
    log_message "Starting integration tests"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Set up test database
    export USE_MEMORY_DB=true
    export USE_MEMORY_REDIS=true
    
    # Run integration tests
    if npm run test:integration:ci; then
        print_success "Integration tests passed"
    else
        exit_code=$?
        print_error "Integration tests failed"
        if [ "$FAIL_FAST" = true ]; then
            return $exit_code
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_message "Integration tests completed in ${duration}s with exit code $exit_code"
    
    return $exit_code
}

run_e2e_tests() {
    if [ "$RUN_E2E" != true ]; then
        return 0
    fi
    
    print_section "Running End-to-End Tests"
    log_message "Starting E2E tests"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Install Playwright browsers if needed
    if [ ! -d "$HOME/.cache/ms-playwright" ]; then
        print_info "Installing Playwright browsers..."
        npx playwright install
    fi
    
    # Run E2E tests
    if npm run test:e2e:ci; then
        print_success "E2E tests passed"
    else
        exit_code=$?
        print_error "E2E tests failed"
        if [ "$FAIL_FAST" = true ]; then
            return $exit_code
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_message "E2E tests completed in ${duration}s with exit code $exit_code"
    
    return $exit_code
}

run_performance_tests() {
    if [ "$RUN_PERFORMANCE" != true ]; then
        return 0
    fi
    
    print_section "Running Performance Tests"
    log_message "Starting performance tests"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Check if application is running
    if ! curl -f "$BASE_URL" > /dev/null 2>&1; then
        print_warning "Application not accessible at $BASE_URL - skipping performance tests"
        return 0
    fi
    
    # Run K6 performance tests
    if npm run test:performance:ci; then
        print_success "Performance tests passed"
    else
        exit_code=$?
        print_error "Performance tests failed"
        if [ "$FAIL_FAST" = true ]; then
            return $exit_code
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_message "Performance tests completed in ${duration}s with exit code $exit_code"
    
    return $exit_code
}

run_security_tests() {
    if [ "$RUN_SECURITY" != true ]; then
        return 0
    fi
    
    print_section "Running Security Tests"
    log_message "Starting security tests"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Check if OWASP ZAP is available
    if ! curl -f "http://localhost:8080" > /dev/null 2>&1; then
        print_warning "OWASP ZAP not accessible - starting ZAP daemon"
        ./scripts/start-zap.sh &
        sleep 10
    fi
    
    # Run security tests
    if npm run test:security:ci; then
        print_success "Security tests passed"
    else
        exit_code=$?
        print_error "Security tests failed"
        if [ "$FAIL_FAST" = true ]; then
            return $exit_code
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_message "Security tests completed in ${duration}s with exit code $exit_code"
    
    return $exit_code
}

generate_consolidated_report() {
    print_section "Generating Consolidated Test Report"
    
    local report_file="$REPORTS_DIR/consolidated-report-$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .metric { background: #fff; border: 1px solid #dee2e6; padding: 15px; border-radius: 8px; text-align: center; }
        .metric.passed { border-left: 4px solid #28a745; }
        .metric.failed { border-left: 4px solid #dc3545; }
        .metric.warning { border-left: 4px solid #ffc107; }
        .test-section { margin-bottom: 30px; }
        .test-results { display: grid; gap: 10px; }
        .test-item { padding: 10px; border-radius: 4px; }
        .test-item.passed { background: #d4edda; }
        .test-item.failed { background: #f8d7da; }
        .timestamp { color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Comprehensive Test Report</h1>
        <p class="timestamp">Generated: $(date)</p>
        <p><strong>Environment:</strong> $TEST_ENV</p>
        <p><strong>Test Execution ID:</strong> $TIMESTAMP</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Duration</h3>
            <h2>$(($(date +%s) - start_time))s</h2>
        </div>
        <div class="metric">
            <h3>Test Types</h3>
            <h2>5</h2>
        </div>
        <div class="metric">
            <h3>Environment</h3>
            <h2>$TEST_ENV</h2>
        </div>
    </div>
    
    <div class="test-section">
        <h2>📊 Test Results Summary</h2>
        <p>Detailed test results and reports are available in the reports directory:</p>
        <ul>
            <li><a href="junit.xml">JUnit Test Results</a></li>
            <li><a href="test-report.html">Jest HTML Report</a></li>
            <li><a href="playwright-report/index.html">Playwright E2E Report</a></li>
            <li><a href="coverage/lcov-report/index.html">Coverage Report</a></li>
        </ul>
    </div>
    
    <div class="test-section">
        <h2>📈 Performance Metrics</h2>
        <p>Performance test results and K6 reports are available in the performance directory.</p>
    </div>
    
    <div class="test-section">
        <h2>🔒 Security Analysis</h2>
        <p>Security test results and OWASP ZAP reports are available in the security directory.</p>
    </div>
</body>
</html>
EOF
    
    print_success "Consolidated report generated: $report_file"
}

cleanup_environment() {
    print_section "Cleaning Up Test Environment"
    
    if [ "$TEST_ENV" = "local" ]; then
        # Stop test services
        docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true
    fi
    
    # Archive test logs
    if [ -f "$LOG_FILE" ]; then
        gzip "$LOG_FILE"
        print_success "Test logs archived: ${LOG_FILE}.gz"
    fi
    
    print_success "Environment cleanup completed"
}

send_notifications() {
    if [ "$SEND_NOTIFICATIONS" != true ]; then
        return 0
    fi
    
    print_section "Sending Test Notifications"
    
    # Implementation depends on your notification system
    # Examples: Slack, email, Teams, etc.
    
    print_info "Notifications sent"
}

# =================================================================
# ARGUMENT PARSING
# =================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env=*)
                TEST_ENV="${1#*=}"
                shift
                ;;
            --type=*)
                TEST_TYPE="${1#*=}"
                shift
                ;;
            --parallel)
                PARALLEL_EXECUTION=true
                shift
                ;;
            --fail-fast)
                FAIL_FAST=true
                shift
                ;;
            --no-coverage)
                GENERATE_COVERAGE=false
                shift
                ;;
            --notify)
                SEND_NOTIFICATIONS=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set test flags based on type
    case "$TEST_TYPE" in
        "unit")
            RUN_INTEGRATION=false
            RUN_E2E=false
            RUN_PERFORMANCE=false
            RUN_SECURITY=false
            ;;
        "integration")
            RUN_UNIT=false
            RUN_E2E=false
            RUN_PERFORMANCE=false
            RUN_SECURITY=false
            ;;
        "e2e")
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_PERFORMANCE=false
            RUN_SECURITY=false
            ;;
        "performance")
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_E2E=false
            RUN_SECURITY=false
            ;;
        "security")
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_E2E=false
            RUN_PERFORMANCE=false
            ;;
        "all")
            # All tests enabled by default
            ;;
        *)
            print_error "Invalid test type: $TEST_TYPE"
            print_info "Valid types: unit, integration, e2e, performance, security, all"
            exit 1
            ;;
    esac
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --env=<environment>    Set test environment (local, staging, production)"
    echo "  --type=<test-type>     Run specific test type (unit, integration, e2e, performance, security, all)"
    echo "  --parallel             Run tests in parallel where possible"
    echo "  --fail-fast            Stop on first test failure"
    echo "  --no-coverage          Skip coverage generation"
    echo "  --notify               Send notifications on completion"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all tests"
    echo "  $0 --type=unit                  # Run only unit tests"
    echo "  $0 --env=staging --parallel     # Run all tests on staging in parallel"
    echo "  $0 --type=security --notify     # Run security tests and send notifications"
}

# =================================================================
# MAIN EXECUTION
# =================================================================

main() {
    local start_time=$(date +%s)
    local overall_exit_code=0
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Setup
    print_banner
    check_prerequisites
    setup_environment
    start_test_services
    
    log_message "Test execution started - Environment: $TEST_ENV, Type: $TEST_TYPE"
    
    # Run tests
    if [ "$PARALLEL_EXECUTION" = true ] && [ "$TEST_TYPE" = "all" ]; then
        print_info "Running tests in parallel..."
        
        # Run unit and integration tests in parallel
        (run_unit_tests; echo $? > /tmp/unit_exit_code) &
        (run_integration_tests; echo $? > /tmp/integration_exit_code) &
        wait
        
        # Check exit codes
        unit_exit_code=$(cat /tmp/unit_exit_code 2>/dev/null || echo 1)
        integration_exit_code=$(cat /tmp/integration_exit_code 2>/dev/null || echo 1)
        
        if [ $unit_exit_code -ne 0 ] || [ $integration_exit_code -ne 0 ]; then
            overall_exit_code=1
        fi
        
        # Run sequential tests
        run_e2e_tests || overall_exit_code=1
        run_performance_tests || overall_exit_code=1
        run_security_tests || overall_exit_code=1
        
        # Cleanup temp files
        rm -f /tmp/unit_exit_code /tmp/integration_exit_code
    else
        # Run tests sequentially
        run_unit_tests || overall_exit_code=1
        run_integration_tests || overall_exit_code=1
        run_e2e_tests || overall_exit_code=1
        run_performance_tests || overall_exit_code=1
        run_security_tests || overall_exit_code=1
    fi
    
    # Generate reports
    generate_consolidated_report
    
    # Cleanup
    cleanup_environment
    send_notifications
    
    # Final summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    print_section "Test Execution Summary"
    log_message "Test execution completed - Duration: ${total_duration}s, Exit code: $overall_exit_code"
    
    if [ $overall_exit_code -eq 0 ]; then
        print_success "All tests completed successfully! ✨"
        print_info "Total execution time: ${total_duration}s"
        print_info "Reports available in: $REPORTS_DIR"
    else
        print_error "Some tests failed! ❌"
        print_info "Check the logs and reports for details"
        print_info "Log file: ${LOG_FILE}.gz"
    fi
    
    exit $overall_exit_code
}

# Execute main function with all arguments
main "$@"
