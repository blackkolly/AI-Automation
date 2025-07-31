# 🚀 Quick Start - Local Development

## How Docker Compose Links the Services

Your Docker Compose setup creates a complete microservices environment with the following architecture:

```
                    ┌─────────────────────┐
                    │    API Gateway      │ ← Entry Point
                    │   localhost:3001    │
                    └──────────┬──────────┘
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
    ┌────────▼────────┐ ┌──────▼──────┐ ┌────────▼────────┐
    │  Auth Service   │ │   Product   │ │  Order Service  │
    │ localhost:3000  │ │   Service   │ │ localhost:3002  │
    └─────────────────┘ │localhost:8080│ └─────────────────┘
                        └─────────────┘
             │                 │                 │
             └─────────────────┼─────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼───────┐    ┌─────────▼─────────┐    ┌───────▼───────┐
│  PostgreSQL   │    │      Redis        │    │     Kafka     │
│ localhost:5432│    │  localhost:6379   │    │localhost:9092 │
└───────────────┘    └───────────────────┘    └───────────────┘
```

## 🔗 Service Communication

### 1. **External Access** (from your browser/client):
- **API Gateway**: `http://localhost:3001` - Main entry point
- **Auth Service**: `http://localhost:3000` - Direct auth access
- **Product Service**: `http://localhost:8080` - Direct product access
- **Order Service**: `http://localhost:3002` - Direct order access

### 2. **Internal Communication** (between containers):
Services use Docker network hostnames:
- `auth-service:3000`
- `product-service:8080`
- `order-service:3002`
- `postgres:5432`
- `redis:6379`
- `kafka:29092`

## 🏃‍♂️ Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Make the script executable
chmod +x dev-setup.sh

# Start everything
./dev-setup.sh start

# View logs
./dev-setup.sh logs

# Stop everything
./dev-setup.sh stop
```

### Option 2: Manual Setup

```bash
# 1. Start infrastructure services first
docker-compose up -d postgres redis kafka zookeeper

# 2. Wait for services to be ready (about 30 seconds)
docker-compose ps

# 3. Start monitoring
docker-compose up -d prometheus grafana jaeger

# 4. Build and start microservices
docker-compose build
docker-compose up -d auth-service api-gateway product-service order-service

# 5. Check everything is running
docker-compose ps
```

## 🧪 Test the Integration

```bash
# 1. Check API Gateway health
curl http://localhost:3001/health

# 2. View API documentation
curl http://localhost:3001/api/docs

# 3. Register a new user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# 4. Login to get JWT token
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 5. Use the JWT token from login response for authenticated requests
curl -X GET http://localhost:3001/api/products \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

## 📊 Access Monitoring

- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Jaeger Tracing**: http://localhost:16686
- **Kafka UI**: http://localhost:8080

## 🗄️ Database Access

```bash
# Connect to PostgreSQL
docker exec -it microservices-postgres psql -U postgres

# List databases
\l

# Connect to specific database
\c auth

# List tables
\dt

# Connect to Redis
docker exec -it microservices-redis redis-cli

# View all keys
KEYS *
```

## 📝 View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f auth-service
docker-compose logs -f api-gateway
docker-compose logs -f product-service
docker-compose logs -f order-service

# Infrastructure
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f kafka
```

## 🔧 Development Workflow

### Making Changes

1. **Node.js services** (auth, api-gateway, order) - changes are hot-reloaded
2. **Spring Boot service** (product) - requires rebuild:
   ```bash
   docker-compose build product-service
   docker-compose up -d product-service
   ```

### Environment Variables

Each service has a `.env.development` file you can modify:
- `services/auth-service/.env.development`
- `services/api-gateway/.env.development`
- `services/product-service/.env.development`
- `services/order-service/.env.development`

## 🛑 Stop & Clean Up

```bash
# Stop all services
docker-compose down

# Stop and remove all data (databases will be reset)
docker-compose down -v

# Remove all images and free space
docker-compose down --rmi all
docker system prune -a
```

## 🔍 Troubleshooting

### Port Conflicts
If you get port conflicts, check what's using the ports:
```bash
# Windows
netstat -ano | findstr :3001

# Linux/Mac
lsof -i :3001
```

### Service Connection Issues
```bash
# Check if services can reach each other
docker exec auth-service ping postgres
docker exec api-gateway ping auth-service

# Check container logs
docker-compose logs postgres
docker-compose logs auth-service
```

### Database Issues
```bash
# Reset databases
docker-compose down -v
docker-compose up -d postgres

# Check database initialization
docker-compose logs postgres
```

## 🎯 Next Steps

1. **Configure OAuth**: Update Google/GitHub client IDs in `.env.development` files
2. **Customize Services**: Modify the business logic in each service
3. **Add Features**: Extend the APIs with new endpoints
4. **Test Integration**: Use the monitoring tools to understand service behavior
5. **Deploy to Kubernetes**: Use the production deployment guide when ready

For detailed information, see `docs/LOCAL_DEVELOPMENT_GUIDE.md`
