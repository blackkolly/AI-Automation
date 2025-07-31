# Local Development Guide

This guide will help you run the microservices platform locally for development and testing.

## Prerequisites

### Required Software
- **Node.js** (v18 or later) - for Node.js services
- **Java** (JDK 17 or later) - for Spring Boot service
- **Maven** (v3.6 or later) - for building Java service
- **Docker** & **Docker Compose** - for databases and infrastructure
- **Git** - for version control

### Installation Commands

#### Windows (using Chocolatey)
```bash
# Install Chocolatey first: https://chocolatey.org/install
choco install nodejs openjdk maven docker-desktop git
```

#### macOS (using Homebrew)
```bash
# Install Homebrew first: https://brew.sh
brew install node openjdk@17 maven docker git
```

#### Ubuntu/Debian
```bash
# Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Java
sudo apt-get install openjdk-17-jdk maven

# Docker
sudo apt-get install docker.io docker-compose-plugin
sudo usermod -aG docker $USER

# Git
sudo apt-get install git
```

## Quick Start (Easy Method)

### Step 1: Start Infrastructure Services
```bash
# Navigate to the project root
cd microservices-platform

# Start databases and supporting services
docker-compose -f docker-compose.local.yml up -d

# Wait for services to be ready (about 30 seconds)
docker-compose -f docker-compose.local.yml ps
```

### Step 2: Install Dependencies
```bash
# Install dependencies for all Node.js services
npm run install:all

# Build Java service
cd services/product-service
mvn clean install -DskipTests
cd ../..
```

### Step 3: Start All Services
```bash
# Start all microservices
npm run dev
```

### Step 4: Verify Services
- **API Gateway**: http://localhost:3001/health
- **Auth Service**: http://localhost:3000/health  
- **Product Service**: http://localhost:8080/actuator/health
- **Order Service**: http://localhost:3002/health
- **API Documentation**: http://localhost:3001/api/docs

## Manual Setup (Step by Step)

### Step 1: Clone and Setup
```bash
git clone <your-repo-url> microservices-platform
cd microservices-platform
```

### Step 2: Environment Configuration
```bash
# Copy environment files
cp .env.example .env
cp services/auth-service/.env.example services/auth-service/.env
cp services/api-gateway/.env.example services/api-gateway/.env
cp services/order-service/.env.example services/order-service/.env
```

### Step 3: Start Infrastructure
```bash
# Start PostgreSQL, Redis, Kafka, and monitoring
docker-compose -f docker-compose.local.yml up -d postgres redis kafka zookeeper

# Wait for databases to be ready
sleep 30

# Check services are running
docker-compose -f docker-compose.local.yml ps
```

### Step 4: Setup Databases
```bash
# Create databases and run migrations
npm run db:setup
```

### Step 5: Start Services Individually

#### Terminal 1 - Auth Service
```bash
cd services/auth-service
npm install
npm run dev
```

#### Terminal 2 - API Gateway  
```bash
cd services/api-gateway
npm install
npm run dev
```

#### Terminal 3 - Product Service
```bash
cd services/product-service
mvn spring-boot:run
```

#### Terminal 4 - Order Service
```bash
cd services/order-service
npm install
npm run dev
```

## Testing the Application

### Health Checks
```bash
# Check all services are healthy
curl http://localhost:3001/health
curl http://localhost:3000/health
curl http://localhost:8080/actuator/health
curl http://localhost:3002/health
```

### API Testing
```bash
# Register a new user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'

# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Use the JWT token from login response for authenticated requests
export JWT_TOKEN="<your-jwt-token>"

# Get products
curl -H "Authorization: Bearer $JWT_TOKEN" \
  http://localhost:3001/api/products

# Create an order
curl -X POST http://localhost:3001/api/orders \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "productId": "1",
    "quantity": 2
  }'
```

## Monitoring and Debugging

### Access Monitoring Services
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Jaeger**: http://localhost:16686
- **Kafka UI**: http://localhost:8080

### View Logs
```bash
# All services logs
docker-compose -f docker-compose.local.yml logs -f

# Specific service logs
npm run logs:auth
npm run logs:gateway
npm run logs:product
npm run logs:order
```

### Database Access
```bash
# PostgreSQL
docker exec -it microservices-postgres psql -U postgres -d microservices

# Redis
docker exec -it microservices-redis redis-cli
```

## Development Workflow

### Code Changes
- **Hot Reload**: Node.js services automatically restart on file changes
- **Java Service**: Restart manually or use Spring Boot DevTools
- **Database Changes**: Run migrations with `npm run db:migrate`

### Running Tests
```bash
# Unit tests for all services
npm run test

# Integration tests
npm run test:integration

# End-to-end tests
npm run test:e2e
```

### Code Quality
```bash
# Linting
npm run lint

# Security scanning
npm run security:scan

# Dependency check
npm run deps:check
```

## Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check what's using a port
netstat -tulpn | grep :3001
# or on Windows
netstat -ano | findstr :3001

# Kill process using port
kill -9 <PID>
# or on Windows
taskkill /PID <PID> /F
```

#### Database Connection Issues
```bash
# Restart databases
docker-compose -f docker-compose.local.yml restart postgres redis

# Check database logs
docker-compose -f docker-compose.local.yml logs postgres
```

#### Service Discovery Issues
```bash
# Verify all services are running
npm run status

# Check service connectivity
curl http://localhost:3001/health
```

#### Memory Issues
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"

# Check system resources
docker stats
```

### Environment Variables

#### Required Variables (.env file)
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=microservices
DB_USER=postgres
DB_PASSWORD=postgres

# Redis
REDIS_URL=redis://localhost:6379

# Kafka
KAFKA_BROKERS=localhost:9092

# Security
JWT_SECRET=your-super-secure-jwt-secret-key-here
JWT_EXPIRES_IN=24h

# OAuth (optional for local development)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret

# Environment
NODE_ENV=development
LOG_LEVEL=debug
```

## IDE Setup

### VS Code Extensions
```json
{
  "recommendations": [
    "ms-vscode.vscode-json",
    "bradlc.vscode-tailwindcss",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-typescript-next",
    "redhat.java",
    "vscjava.vscode-spring-initializr",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "ms-azuretools.vscode-docker"
  ]
}
```

### Debug Configuration
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Auth Service",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/services/auth-service/src/app.js",
      "env": {
        "NODE_ENV": "development"
      }
    },
    {
      "name": "Debug API Gateway",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/services/api-gateway/src/app.js",
      "env": {
        "NODE_ENV": "development"
      }
    }
  ]
}
```

## Performance Tips

### Development Optimizations
```bash
# Use local DNS resolution
echo "127.0.0.1 auth-service" >> /etc/hosts
echo "127.0.0.1 api-gateway" >> /etc/hosts
echo "127.0.0.1 product-service" >> /etc/hosts
echo "127.0.0.1 order-service" >> /etc/hosts

# Disable unnecessary logging in development
export LOG_LEVEL=warn

# Use faster package manager
npm install -g pnpm
pnpm install
```

### Resource Monitoring
```bash
# Monitor resource usage
npm run monitor

# Check service health
npm run health:check
```

## Next Steps

1. **Set up your IDE** with the recommended extensions
2. **Configure debugging** for step-through debugging
3. **Run the test suite** to ensure everything works
4. **Explore the API** using the documentation endpoint
5. **Make your first code change** and see hot reload in action

For deployment to cloud environments, see [DEPLOYMENT.md](./DEPLOYMENT.md).

## Getting Help

- **API Documentation**: http://localhost:3001/api/docs
- **Service Health**: http://localhost:3001/health
- **Logs**: `npm run logs`
- **GitHub Issues**: Create an issue in the repository

Happy coding! 🚀
