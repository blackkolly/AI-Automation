# Docker Compose Service Linking Explained

This document explains how the Docker Compose file links the microservices with infrastructure components and each other.

## 🔗 Service Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                       │
│                  (microservices-network)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ PostgreSQL  │    │    Redis    │    │    Kafka    │         │
│  │   :5432     │    │   :6379     │    │   :29092    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┼──────────────│
│                             │                   │              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │Auth Service │    │Product Svc  │    │Order Service│         │
│  │   :3000     │    │   :8080     │    │   :3002     │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┘              │
│                             │                                  │
│                    ┌─────────────┐                             │
│                    │ API Gateway │                             │
│                    │   :3001     │                             │
│                    └─────────────┘                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ How Services Link Together

### 1. **Build Context Linking**
Each service is built from its source code directory:

```yaml
auth-service:
  build:
    context: ./services/auth-service  # 📁 Links to source code
    dockerfile: Dockerfile           # 🐳 Uses service's Dockerfile
```

### 2. **Network Communication**
All services are on the same Docker network, enabling communication by service name:

```yaml
networks:
  - microservices-network  # 🌐 All services join this network
```

### 3. **Environment Variables for Service Discovery**
The API Gateway knows how to reach other services through environment variables:

```yaml
api-gateway:
  environment:
    AUTH_SERVICE_URL: http://auth-service:3000      # 🔗 Links to auth service
    PRODUCT_SERVICE_URL: http://product-service:8080 # 🔗 Links to product service
    ORDER_SERVICE_URL: http://order-service:3002     # 🔗 Links to order service
```

### 4. **Database Connections**
Services connect to PostgreSQL using the container name as hostname:

```yaml
auth-service:
  environment:
    DB_HOST: postgres  # 🗄️ Links to PostgreSQL container
    DB_NAME: auth      # 📊 Uses dedicated database
    
product-service:
  environment:
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/products
    
order-service:
  environment:
    DB_HOST: postgres
    DB_NAME: orders
```

### 5. **Redis Cache Connections**
All services can access Redis using the container name:

```yaml
environment:
  REDIS_HOST: redis  # 🔴 Links to Redis container
  REDIS_PORT: 6379
```

### 6. **Kafka Event Streaming**
Order service connects to Kafka for event processing:

```yaml
order-service:
  environment:
    KAFKA_BROKERS: kafka:29092  # 📨 Links to Kafka container
```

### 7. **Service Dependencies**
Services wait for infrastructure to be healthy before starting:

```yaml
auth-service:
  depends_on:
    postgres:
      condition: service_healthy  # ⏳ Wait for PostgreSQL
    redis:
      condition: service_healthy  # ⏳ Wait for Redis

api-gateway:
  depends_on:
    - auth-service  # ⏳ Wait for auth service to start
```

## 📂 Volume Mounting for Development

Services mount their source code for live reload during development:

```yaml
volumes:
  - ./services/auth-service:/app      # 🔄 Live code reload
  - /app/node_modules                 # 📦 Preserve node_modules
```

## 🌐 Port Mapping

External access to services through port mapping:

```yaml
ports:
  - "3001:3001"  # API Gateway (main entry point)
  - "3000:3000"  # Auth Service (direct access for testing)
  - "8080:8080"  # Product Service (direct access for testing)
  - "3002:3002"  # Order Service (direct access for testing)
  - "5432:5432"  # PostgreSQL (database access)
  - "6379:6379"  # Redis (cache access)
```

## 🔄 Service Communication Flow

1. **Client Request** → API Gateway (:3001)
2. **API Gateway** → Routes to appropriate service:
   - `/api/auth/*` → Auth Service (:3000)
   - `/api/products/*` → Product Service (:8080)
   - `/api/orders/*` → Order Service (:3002)
3. **Services** → Connect to:
   - PostgreSQL for data persistence
   - Redis for caching and sessions
   - Kafka for event streaming (orders)

## 🛠️ Development Workflow

1. **Source Code Changes**: Automatically reflected due to volume mounting
2. **Service Restart**: `docker-compose restart <service-name>`
3. **Logs**: `docker-compose logs -f <service-name>`
4. **Database Access**: Connect to localhost:5432
5. **Cache Access**: Connect to localhost:6379

## 🔧 Key Linking Mechanisms

| Mechanism | Purpose | Example |
|-----------|---------|---------|
| **Service Names** | Internal DNS resolution | `http://auth-service:3000` |
| **Environment Variables** | Service URLs and config | `AUTH_SERVICE_URL=http://auth-service:3000` |
| **Depends On** | Startup ordering | `depends_on: postgres` |
| **Health Checks** | Service readiness | `condition: service_healthy` |
| **Shared Network** | Container communication | `microservices-network` |
| **Volume Mounts** | Live code reloading | `./services/auth-service:/app` |

## 🚀 Quick Start Commands

```bash
# Start all services
docker-compose -f docker-compose.local.yml up -d

# Start specific service
docker-compose -f docker-compose.local.yml up auth-service

# View logs
docker-compose -f docker-compose.local.yml logs -f api-gateway

# Scale a service
docker-compose -f docker-compose.local.yml up --scale auth-service=3

# Stop all services
docker-compose -f docker-compose.local.yml down
```

This setup enables complete local development with all services communicating seamlessly!
