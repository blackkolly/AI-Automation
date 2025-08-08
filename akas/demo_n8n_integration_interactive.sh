#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    print_success "Docker is available"
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    print_success "Docker Compose is available"
    
    if [ ! -f "docker-compose-test-enhanced.yml" ]; then
        print_error "docker-compose-test-enhanced.yml not found"
        exit 1
    fi
    print_success "Docker Compose file found"
    
    echo ""
}

# Start services
start_services() {
    print_header "Starting Enhanced AKAS with n8n Integration"
    
    print_info "Building and starting services..."
    docker-compose -f docker-compose-test-enhanced.yml up -d --build
    
    print_info "Waiting for services to initialize..."
    sleep 15
    echo ""
}

# Check service health
check_service_health() {
    print_header "Service Health Check"
    
    # Check backend
    if curl -s -f http://localhost:8000/v2/health/ > /dev/null 2>&1; then
        print_success "Backend: Ready (http://localhost:8000)"
        
        # Get n8n status from backend
        n8n_status=$(curl -s http://localhost:8000/v2/n8n-status/ 2>/dev/null)
        if echo "$n8n_status" | grep -q '"n8n_enabled": true'; then
            print_success "n8n Integration: Enabled"
        else
            print_warning "n8n Integration: Disabled or not ready"
        fi
    else
        print_error "Backend: Not ready"
    fi
    
    # Check frontend
    if curl -s -f http://localhost:8501 > /dev/null 2>&1; then
        print_success "Frontend: Ready (http://localhost:8501)"
    else
        print_error "Frontend: Not ready"
    fi
    
    # Check n8n directly
    if curl -s -f http://localhost:5678 > /dev/null 2>&1; then
        print_success "n8n Interface: Ready (http://localhost:5678)"
    else
        print_error "n8n Interface: Not ready"
    fi
    
    echo ""
}

# Show test URLs
show_test_urls() {
    print_header "Test URLs & Access Points"
    
    echo "🌐 Main Interfaces:"
    echo "   Frontend (with n8n tab):     http://localhost:8501"
    echo "   n8n Workflow Interface:      http://localhost:5678 (admin/password)"
    echo "   Backend API Documentation:   http://localhost:8000/docs"
    echo ""
    echo "🔧 API Endpoints:"
    echo "   Health Check (with n8n):     http://localhost:8000/v2/health/"
    echo "   n8n Status:                  http://localhost:8000/v2/n8n-status/"
    echo "   Manual Workflow Trigger:     http://localhost:8000/v2/trigger-workflow/"
    echo ""
}

# Show differences
show_differences() {
    print_header "Visible Differences With n8n Integration"
    
    echo -e "${RED}WITHOUT n8n:${NC}"
    echo "  - No workflow tab in frontend"
    echo "  - Upload returns only: {\"results\": [...]}"
    echo "  - No automation capabilities"
    echo "  - No external system integration"
    echo ""
    echo -e "${GREEN}WITH n8n:${NC}"
    echo "  - Dedicated \"n8n Workflows\" tab in frontend"
    echo "  - Upload returns: {\"results\": [...], \"n8n_workflow\": {...}}"
    echo "  - Real-time workflow status in sidebar"
    echo "  - Manual workflow testing interface"
    echo "  - Workflow history and monitoring"
    echo "  - External system integration capabilities"
    echo ""
}

# Interactive test menu
interactive_tests() {
    print_header "Interactive Testing"
    
    while true; do
        echo "Select a test to run:"
        echo "1) Test backend health"
        echo "2) Test n8n status"
        echo "3) Trigger test workflow"
        echo "4) View service logs"
        echo "5) Open URLs in browser (if available)"
        echo "6) Show service status"
        echo "0) Exit testing"
        echo ""
        read -p "Enter your choice: " choice
        
        case $choice in
            1)
                echo ""
                print_info "Testing backend health..."
                curl -s http://localhost:8000/v2/health/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/v2/health/
                echo ""
                ;;
            2)
                echo ""
                print_info "Testing n8n status..."
                curl -s http://localhost:8000/v2/n8n-status/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/v2/n8n-status/
                echo ""
                ;;
            3)
                echo ""
                print_info "Triggering test workflow..."
                curl -X POST "http://localhost:8000/v2/trigger-workflow/?workflow_name=test" \
                     -H "Content-Type: application/json" \
                     -d '{"test": true, "message": "Demo test"}' | python3 -m json.tool 2>/dev/null || \
                curl -X POST "http://localhost:8000/v2/trigger-workflow/?workflow_name=test" \
                     -H "Content-Type: application/json" \
                     -d '{"test": true, "message": "Demo test"}'
                echo ""
                ;;
            4)
                echo ""
                print_info "Service logs (last 20 lines):"
                docker-compose -f docker-compose-test-enhanced.yml logs --tail=20
                echo ""
                ;;
            5)
                echo ""
                print_info "Attempting to open URLs..."
                if command -v xdg-open &> /dev/null; then
                    xdg-open "http://localhost:8501" &>/dev/null &
                    xdg-open "http://localhost:5678" &>/dev/null &
                elif command -v open &> /dev/null; then
                    open "http://localhost:8501" &>/dev/null &
                    open "http://localhost:5678" &>/dev/null &
                else
                    print_warning "No browser opener found. Please manually open:"
                    echo "  http://localhost:8501"
                    echo "  http://localhost:5678"
                fi
                echo ""
                ;;
            6)
                echo ""
                check_service_health
                ;;
            0)
                break
                ;;
            *)
                print_warning "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    print_header "Cleaning Up"
    
    print_info "Stopping all services..."
    docker-compose -f docker-compose-test-enhanced.yml down
    
    print_success "Demo completed!"
    echo ""
}

# Main script execution
main() {
    echo ""
    print_header "AKAS n8n Integration Demonstration"
    
    check_prerequisites
    start_services
    check_service_health
    show_test_urls
    show_differences
    
    echo "Press Enter to continue to interactive testing..."
    read -r
    
    interactive_tests
    cleanup
}

# Handle Ctrl+C gracefully
trap cleanup EXIT

# Run main function
main
