#!/bin/bash

# Local Development Setup Script
# This script sets up the microservices platform for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
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

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

cleanup_existing() {
    print_header "Cleaning Up Existing Containers"
    
    # Stop and remove existing containers
    docker-compose down -v 2>/dev/null || true
    
    # Remove any orphaned containers
    docker-compose down --remove-orphans 2>/dev/null || true
    
    print_success "Cleanup completed"
}

start_infrastructure() {
    print_header "Starting Infrastructure Services"
    
    # Start infrastructure services first
    docker-compose up -d postgres redis zookeeper kafka
    
    # Wait for databases to be ready
    echo "Waiting for PostgreSQL to be ready..."
    timeout 60 bash -c 'until docker exec microservices-postgres pg_isready -U postgres; do sleep 2; done' || {
        print_error "PostgreSQL failed to start"
        exit 1
    }
    
    echo "Waiting for Redis to be ready..."
    timeout 60 bash -c 'until docker exec microservices-redis redis-cli ping; do sleep 2; done' || {
        print_error "Redis failed to start"
        exit 1
    }
    
    echo "Waiting for Kafka to be ready..."
    sleep 30  # Kafka takes longer to start
    
    print_success "Infrastructure services started"
}

start_monitoring() {
    print_header "Starting Monitoring Services"
    
    # Start monitoring stack
    docker-compose up -d prometheus grafana jaeger kafka-ui
    
    print_success "Monitoring services started"
}

build_and_start_services() {
    print_header "Building and Starting Microservices"
    
    # Build all microservices
    echo "Building microservices..."
    docker-compose build auth-service api-gateway product-service order-service
    
    # Start microservices
    echo "Starting microservices..."
    docker-compose up -d auth-service api-gateway product-service order-service
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 30
    
    print_success "Microservices started"
}

verify_services() {
    print_header "Verifying Services"
    
    # Check if all containers are running
    echo "Container Status:"
    docker-compose ps
    
    # Test health endpoints
    echo -e "\nTesting health endpoints..."
    
    # Test API Gateway
    if curl -s http://localhost:3001/health > /dev/null; then
        print_success "API Gateway is healthy"
    else
        print_warning "API Gateway health check failed"
    fi
    
    # Test Auth Service
    if curl -s http://localhost:3000/health > /dev/null; then
        print_success "Auth Service is healthy"
    else
        print_warning "Auth Service health check failed"
    fi
    
    # Test Product Service
    if curl -s http://localhost:8080/actuator/health > /dev/null; then
        print_success "Product Service is healthy"
    else
        print_warning "Product Service health check failed"
    fi
    
    # Test Order Service
    if curl -s http://localhost:3002/health > /dev/null; then
        print_success "Order Service is healthy"
    else
        print_warning "Order Service health check failed"
    fi
}

show_access_info() {
    print_header "🎉 Local Development Environment Ready!"
    
    echo -e "${GREEN}Services are running at:${NC}"
    echo "🌐 API Gateway:     http://localhost:3001"
    echo "🔐 Auth Service:    http://localhost:3000"
    echo "📦 Product Service: http://localhost:8080"
    echo "📋 Order Service:   http://localhost:3002"
    echo ""
    echo -e "${GREEN}Monitoring & Tools:${NC}"
    echo "📊 Grafana:         http://localhost:3001 (admin/admin)"
    echo "📈 Prometheus:      http://localhost:9090"
    echo "🔍 Jaeger:          http://localhost:16686"
    echo "📨 Kafka UI:        http://localhost:8080"
    echo "📧 Mailhog:         http://localhost:8025"
    echo ""
    echo -e "${GREEN}Database Connections:${NC}"
    echo "🗄️  PostgreSQL:     localhost:5432 (postgres/postgres)"
    echo "🔴 Redis:           localhost:6379"
    echo "📬 Kafka:           localhost:9092"
    echo ""
    echo -e "${YELLOW}Quick API Test:${NC}"
    echo "# Test API Gateway"
    echo "curl http://localhost:3001/api/docs"
    echo ""
    echo "# Register a user"
    echo "curl -X POST http://localhost:3001/api/auth/register \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"email\":\"test@example.com\",\"password\":\"password123\",\"name\":\"Test User\"}'"
    echo ""
    echo -e "${BLUE}View logs: docker-compose logs -f [service-name]${NC}"
    echo -e "${BLUE}Stop services: docker-compose down${NC}"
    echo -e "${BLUE}Full cleanup: docker-compose down -v${NC}"
}

show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  start     Start all services (default)"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  logs      Show logs for all services"
    echo "  status    Show status of all services"
    echo "  clean     Stop services and remove volumes"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start          # Start the development environment"
    echo "  $0 logs           # View logs"
    echo "  $0 clean          # Clean up everything"
}

case "${1:-start}" in
    "start")
        check_prerequisites
        cleanup_existing
        start_infrastructure
        start_monitoring
        build_and_start_services
        verify_services
        show_access_info
        ;;
    "stop")
        print_header "Stopping Services"
        docker-compose down
        print_success "All services stopped"
        ;;
    "restart")
        print_header "Restarting Services"
        docker-compose down
        sleep 5
        docker-compose up -d
        print_success "All services restarted"
        ;;
    "logs")
        docker-compose logs -f
        ;;
    "status")
        print_header "Service Status"
        docker-compose ps
        ;;
    "clean")
        print_header "Cleaning Up"
        docker-compose down -v
        docker system prune -f
        print_success "Cleanup completed"
        ;;
    "help")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
