# Local Development Guide

This guide explains how to run the microservices platform locally using Docker Compose.

## 🏗️ How Docker Compose Links Services

### Service Linking Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │────│  Auth Service   │    │ Product Service │
│   (Port 3001)   │    │   (Port 3000)   │    │   (Port 8080)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  │
                    ┌─────────────────┐
                    │  Order Service  │
                    │   (Port 3002)   │
                    └─────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   PostgreSQL    │  │      Redis      │  │     Kafka       │
│   (Port 5432)   │  │   (Port 6379)   │  │   (Port 9092)   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Service Communication

1. **API Gateway (`api-gateway:3001`)**
   - Acts as the entry point for all client requests
   - Routes requests to appropriate microservices
   - Handles authentication, rate limiting, and load balancing
   - Environment variables define service URLs:
     ```
     AUTH_SERVICE_URL=http://auth-service:3000
     PRODUCT_SERVICE_URL=http://product-service:8080
     ORDER_SERVICE_URL=http://order-service:3002
     ```

2. **Auth Service (`auth-service:3000`)**
   - Handles user authentication and authorization
   - Connects to PostgreSQL for user data
   - Uses Redis for session storage
   - Environment variables:
     ```
     DB_HOST=postgres
     REDIS_HOST=redis
     ```

3. **Product Service (`product-service:8080`)**
   - Manages product catalog
   - Spring Boot application
   - Connects to PostgreSQL for product data
   - Uses Redis for caching
   - Environment variables:
     ```
     SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/products
     SPRING_REDIS_HOST=redis
     ```

4. **Order Service (`order-service:3002`)**
   - Handles order processing
   - Publishes/consumes Kafka events
   - Connects to PostgreSQL for order data
   - Communicates with Product Service for product validation
   - Environment variables:
     ```
     DB_HOST=postgres
     KAFKA_BROKERS=kafka:29092
     PRODUCT_SERVICE_URL=http://product-service:8080
     ```

### Network Configuration

All services run on the `microservices-network` bridge network, which allows:
- **Service Discovery**: Services can communicate using container names as hostnames
- **DNS Resolution**: Docker's built-in DNS resolves `auth-service`, `postgres`, etc.
- **Port Isolation**: Internal communication uses container ports, external access uses mapped ports

## 🚀 Quick Start

### Prerequisites

```bash
# Install Docker and Docker Compose
# Windows: Download Docker Desktop
# Linux: 
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Step 1: Clone and Navigate

```bash
cd microservices-platform
```

### Step 2: Start Infrastructure Services

```bash
# Start only the infrastructure (databases, message queues, monitoring)
docker-compose up -d postgres redis kafka zookeeper prometheus grafana jaeger

# Wait for services to be healthy
docker-compose ps
```

### Step 3: Build and Start Microservices

```bash
# Build all microservices
docker-compose build auth-service api-gateway product-service order-service

# Start all services
docker-compose up -d

# Or start specific services
docker-compose up -d auth-service
docker-compose up -d product-service
docker-compose up -d order-service
docker-compose up -d api-gateway
```

### Step 4: Verify Services

```bash
# Check all services are running
docker-compose ps

# Check logs
docker-compose logs auth-service
docker-compose logs api-gateway
docker-compose logs product-service
docker-compose logs order-service

# Test API endpoints
curl http://localhost:3001/health
curl http://localhost:3000/health
curl http://localhost:8080/actuator/health
curl http://localhost:3002/health
```

## 🔗 Service Endpoints

### External Access (from your host machine)

| Service | URL | Description |
|---------|-----|-------------|
| API Gateway | http://localhost:3001 | Main entry point |
| Auth Service | http://localhost:3000 | Direct auth access |
| Product Service | http://localhost:8080 | Direct product access |
| Order Service | http://localhost:3002 | Direct order access |
| Grafana | http://localhost:3001 | Monitoring dashboard |
| Prometheus | http://localhost:9090 | Metrics server |
| Jaeger | http://localhost:16686 | Tracing UI |
| Kafka UI | http://localhost:8080 | Kafka management |
| Mailhog | http://localhost:8025 | Email testing |

### Internal Communication (between containers)

Services communicate using Docker network hostnames:
```javascript
// In API Gateway
const authServiceUrl = 'http://auth-service:3000';
const productServiceUrl = 'http://product-service:8080';
const orderServiceUrl = 'http://order-service:3002';
```

## 🗄️ Database Configuration

### Multiple Databases

The PostgreSQL container creates separate databases:
- `auth` - User authentication data
- `products` - Product catalog data
- `orders` - Order transaction data

### Connection Details

```
Host: localhost (from host) or postgres (from containers)
Port: 5432
Username: postgres
Password: postgres
Databases: auth, products, orders
```

### Database Initialization

The `init-databases.sql` script runs automatically when PostgreSQL starts for the first time, creating:
- Multiple databases
- Separate users for each service (optional)
- Proper permissions

## 📊 Monitoring Setup

### Prometheus Targets

The `monitoring/prometheus.yml` configures scraping from:
- `auth-service:3000/metrics`
- `api-gateway:3001/metrics`
- `product-service:8080/actuator/prometheus`
- `order-service:3002/metrics`

### Grafana Dashboards

Access Grafana at http://localhost:3001 (admin/admin) to view:
- Service metrics
- Database performance
- Kafka message flow
- Custom business metrics

## 🔧 Development Workflow

### Making Code Changes

1. **For Node.js services** (auth, api-gateway, order):
   ```bash
   # Code changes are automatically reflected (if using nodemon)
   # Or restart the specific service
   docker-compose restart auth-service
   ```

2. **For Spring Boot service** (product):
   ```bash
   # Rebuild and restart
   docker-compose build product-service
   docker-compose up -d product-service
   ```

### Environment Variables

Each service has a `.env.development` file with all necessary configuration. Modify these files to change:
- Database connections
- Service URLs
- Authentication secrets
- Feature flags

### Testing the Integration

```bash
# 1. Register a user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# 2. Login to get JWT token
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Use token to access products (replace TOKEN with actual JWT)
curl -X GET http://localhost:3001/api/products \
  -H "Authorization: Bearer TOKEN"

# 4. Create an order
curl -X POST http://localhost:3001/api/orders \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"quantity":2}'
```

## 📝 Logs and Debugging

### View Service Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f auth-service
docker-compose logs -f api-gateway

# Last 100 lines
docker-compose logs --tail=100 product-service
```

### Database Access

```bash
# Connect to PostgreSQL
docker exec -it microservices-postgres psql -U postgres -d auth

# View tables
\dt

# Query users
SELECT * FROM users;
```

### Redis Debugging

```bash
# Connect to Redis
docker exec -it microservices-redis redis-cli

# View all keys
KEYS *

# Check session data
GET "session:your-session-id"
```

## 🛑 Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (data will be lost)
docker-compose down -v

# Stop specific service
docker-compose stop auth-service
```

## 🧹 Cleanup

```bash
# Remove all containers and networks
docker-compose down

# Remove volumes (database data will be lost)
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Clean up Docker system
docker system prune -a
```

## 🔍 Troubleshooting

### Common Issues

1. **Port conflicts**
   ```bash
   # Check what's using a port
   netstat -tlnp | grep :3001
   
   # Change port in docker-compose.yml
   ports:
     - "3002:3001"  # Host:Container
   ```

2. **Services can't connect to databases**
   ```bash
   # Check if postgres is ready
   docker-compose logs postgres
   
   # Verify network connectivity
   docker exec auth-service ping postgres
   ```

3. **Build failures**
   ```bash
   # Rebuild without cache
   docker-compose build --no-cache auth-service
   
   # Check Dockerfile syntax
   docker build services/auth-service/
   ```

### Health Checks

All services include health check endpoints:
- Auth Service: `GET /health`
- API Gateway: `GET /health`
- Product Service: `GET /actuator/health`
- Order Service: `GET /health`

## 🔄 Service Dependencies

The Docker Compose file uses `depends_on` with health checks:

```yaml
auth-service:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
```

This ensures services start in the correct order and wait for dependencies to be ready.

## 🌐 External Integrations

For full functionality, configure:

1. **OAuth Providers**: Update client IDs and secrets in `.env.development` files
2. **Email Service**: Mailhog is configured for development email testing
3. **File Storage**: MinIO provides S3-compatible storage locally
4. **Message Queue**: Kafka handles asynchronous communication

This setup provides a complete development environment that mirrors the production Kubernetes deployment!
