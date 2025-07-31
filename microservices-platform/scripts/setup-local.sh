#!/bin/bash

# Quick setup script for local development

echo "🚀 Setting up Microservices Platform for local development..."

# Check if required tools are installed
echo "Checking prerequisites..."

command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed. Please install Node.js 18+ first."; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ npm is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo "❌ Maven is required but not installed."; exit 1; }
command -v java >/dev/null 2>&1 || { echo "❌ Java is required but not installed."; exit 1; }

echo "✅ All prerequisites found!"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo "✅ Created .env file from template"
else
    echo "✅ .env file already exists"
fi

# Create individual service .env files
echo "📝 Creating service environment files..."

# Auth Service
if [ ! -f services/auth-service/.env ]; then
    cat > services/auth-service/.env << EOF
NODE_ENV=development
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=microservices
DB_USER=postgres
DB_PASSWORD=postgres
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-super-secure-jwt-secret-key-for-local-development-only
JWT_EXPIRES_IN=24h
LOG_LEVEL=debug
EOF
    echo "✅ Created auth-service .env file"
fi

# API Gateway
if [ ! -f services/api-gateway/.env ]; then
    cat > services/api-gateway/.env << EOF
NODE_ENV=development
PORT=3001
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-super-secure-jwt-secret-key-for-local-development-only
AUTH_SERVICE_URL=http://localhost:3000
PRODUCT_SERVICE_URL=http://localhost:8080
ORDER_SERVICE_URL=http://localhost:3002
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001,http://localhost:8080
LOG_LEVEL=debug
EOF
    echo "✅ Created api-gateway .env file"
fi

# Order Service
if [ ! -f services/order-service/.env ]; then
    cat > services/order-service/.env << EOF
NODE_ENV=development
PORT=3002
DB_HOST=localhost
DB_PORT=5432
DB_NAME=microservices
DB_USER=postgres
DB_PASSWORD=postgres
REDIS_URL=redis://localhost:6379
KAFKA_BROKERS=localhost:9092
JWT_SECRET=your-super-secure-jwt-secret-key-for-local-development-only
LOG_LEVEL=debug
EOF
    echo "✅ Created order-service .env file"
fi

# Product Service application.properties
if [ ! -f services/product-service/src/main/resources/application-local.properties ]; then
    mkdir -p services/product-service/src/main/resources
    cat > services/product-service/src/main/resources/application-local.properties << EOF
server.port=8080
spring.application.name=product-service

# Database configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/microservices
spring.datasource.username=postgres
spring.datasource.password=postgres
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA configuration
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

# Redis configuration
spring.redis.host=localhost
spring.redis.port=6379
spring.redis.timeout=2000ms

# Logging
logging.level.com.microservices.product=DEBUG
logging.level.org.springframework.web=DEBUG

# Security
jwt.secret=your-super-secure-jwt-secret-key-for-local-development-only
jwt.expiration=86400000

# Metrics
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoint.health.show-details=always
management.metrics.export.prometheus.enabled=true
EOF
    echo "✅ Created product-service application-local.properties file"
fi

echo "🐳 Starting infrastructure services with Docker Compose..."
docker-compose -f docker-compose.local.yml up -d

echo "⏳ Waiting for services to start..."
sleep 30

echo "📦 Installing dependencies..."
npm install

# Install Node.js service dependencies
echo "Installing auth-service dependencies..."
cd services/auth-service && npm install && cd ../..

echo "Installing api-gateway dependencies..."
cd services/api-gateway && npm install && cd ../..

echo "Installing order-service dependencies..."
cd services/order-service && npm install && cd ../..

# Build Java service
echo "Building product-service..."
cd services/product-service && mvn clean install -DskipTests && cd ../..

echo "🗄️ Setting up databases..."
# Wait a bit more for databases to be fully ready
sleep 10

# Create database initialization script
cat > scripts/init-databases.sql << 'EOF'
-- Create databases for each service
CREATE DATABASE IF NOT EXISTS auth;
CREATE DATABASE IF NOT EXISTS products;
CREATE DATABASE IF NOT EXISTS orders;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE auth TO postgres;
GRANT ALL PRIVILEGES ON DATABASE products TO postgres;
GRANT ALL PRIVILEGES ON DATABASE orders TO postgres;
EOF

echo "✅ Database initialization script created"

echo "🔍 Checking service health..."
echo "Checking PostgreSQL..."
docker exec microservices-postgres pg_isready -U postgres || echo "⚠️ PostgreSQL not ready yet"

echo "Checking Redis..."
docker exec microservices-redis redis-cli ping || echo "⚠️ Redis not ready yet"

echo "Checking Kafka..."
docker exec microservices-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 || echo "⚠️ Kafka not ready yet"

echo ""
echo "🎉 Setup completed!"
echo ""
echo "🚀 To start all services, run:"
echo "   npm run dev"
echo ""
echo "📊 Access points:"
echo "   API Gateway:    http://localhost:3001"
echo "   Auth Service:   http://localhost:3000"
echo "   Product Service: http://localhost:8080"
echo "   Order Service:  http://localhost:3002"
echo ""
echo "🔧 Monitoring:"
echo "   Prometheus:     http://localhost:9090"
echo "   Grafana:        http://localhost:3001 (admin/admin)"
echo "   Kafka UI:       http://localhost:8080"
echo "   Jaeger:         http://localhost:16686"
echo ""
echo "📚 API Documentation: http://localhost:3001/api/docs"
echo ""
echo "💡 Useful commands:"
echo "   npm run health:check  - Check all service health"
echo "   npm run logs         - View all logs"
echo "   npm run docker:down  - Stop infrastructure"
echo ""
echo "Happy coding! 🚀"
