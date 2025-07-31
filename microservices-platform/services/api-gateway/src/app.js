const express = require('express');
const httpProxyMiddleware = require('http-proxy-middleware');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const Redis = require('redis');
const promMiddleware = require('express-prometheus-middleware');
require('dotenv').config();

const logger = require('./utils/logger');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

// Redis client for caching and rate limiting
const redisClient = Redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});

redisClient.on('error', (err) => logger.error('Redis Client Error', err));
redisClient.connect();

// Prometheus metrics
app.use(promMiddleware({
  metricsPath: '/metrics',
  collectDefaultMetrics: true,
  requestDurationBuckets: [0.1, 0.5, 1, 1.5],
}));

// Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      connectSrc: ["'self'", "https:", "wss:"],
    },
  },
}));

// CORS
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));

// Advanced rate limiting with Redis
const createRateLimiter = (windowMs, max, keyGenerator) => {
  return rateLimit({
    windowMs,
    max,
    keyGenerator,
    store: {
      incr: async (key) => {
        const current = await redisClient.incr(key);
        if (current === 1) {
          await redisClient.expire(key, Math.ceil(windowMs / 1000));
        }
        return { totalHits: current };
      },
      decrement: async (key) => {
        await redisClient.decr(key);
      },
      resetKey: async (key) => {
        await redisClient.del(key);
      },
    },
    message: 'Too many requests, please try again later.',
  });
};

// Global rate limit
app.use(createRateLimiter(15 * 60 * 1000, 1000, (req) => req.ip));

// Service-specific rate limits
const authLimiter = createRateLimiter(15 * 60 * 1000, 20, (req) => req.ip);
const productLimiter = createRateLimiter(15 * 60 * 1000, 100, (req) => req.ip);

// JWT authentication middleware
const authenticateJWT = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required'
    });
  }

  try {
    // Check if token is blacklisted
    const blacklisted = await redisClient.get(`blacklist_${token}`);
    if (blacklisted) {
      return res.status(401).json({
        success: false,
        message: 'Token has been revoked'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    logger.error('JWT verification failed:', error);
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired token'
    });
  }
};

// Conditional authentication middleware for products (allow public GET requests)
const authenticateJWTConditional = async (req, res, next) => {
  // Allow public GET requests to browse products
  if (req.method === 'GET') {
    return next();
  }
  
  // Require authentication for POST, PUT, DELETE operations
  return authenticateJWT(req, res, next);
};

// Request logging
app.use((req, res, next) => {
  const requestId = req.headers['x-request-id'] || 
    Math.random().toString(36).substr(2, 9);
  
  req.requestId = requestId;
  
  logger.info(`Gateway request: ${req.method} ${req.originalUrl}`, {
    requestId,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: req.user?.userId,
  });
  
  next();
});

// Load balancing configuration
const serviceInstances = {
  auth: [
    'http://auth-service:3001',
    // Add more instances for load balancing
  ],
  product: [
    'http://product-service:8080',
    // Add more instances for load balancing
  ],
  order: [
    'http://order-service:3003',
    // Add more instances for load balancing
  ],
};

// Circuit breaker implementation
class CircuitBreaker {
  constructor(service, threshold = 5, resetTimeout = 60000) {
    this.service = service;
    this.threshold = threshold;
    this.resetTimeout = resetTimeout;
    this.failures = 0;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.lastFailureTime = null;
  }

  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.failures = 0;
      } else {
        throw new Error(`Circuit breaker OPEN for ${this.service}`);
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    
    if (this.failures >= this.threshold) {
      this.state = 'OPEN';
      logger.error(`Circuit breaker OPEN for ${this.service}`);
    }
  }
}

const circuitBreakers = {
  auth: new CircuitBreaker('auth-service'),
  product: new CircuitBreaker('product-service'),
  order: new CircuitBreaker('order-service'),
};

// Service discovery and load balancing
const getServiceInstance = (serviceName) => {
  const instances = serviceInstances[serviceName];
  if (!instances || instances.length === 0) {
    throw new Error(`No instances available for ${serviceName}`);
  }
  
  // Simple round-robin load balancing
  const instanceIndex = Math.floor(Math.random() * instances.length);
  return instances[instanceIndex];
};

// Proxy configuration with circuit breaker
const createServiceProxy = (serviceName, pathRewrite) => {
  return async (req, res, next) => {
    try {
      const target = getServiceInstance(serviceName);
      
      await circuitBreakers[serviceName].call(async () => {
        const proxy = httpProxyMiddleware({
          target,
          changeOrigin: true,
          pathRewrite,
          timeout: 30000,
          proxyTimeout: 30000,
          onProxyReq: (proxyReq, req, res) => {
            // Add request ID header
            proxyReq.setHeader('X-Request-ID', req.requestId);
            
            // Add user context
            if (req.user) {
              proxyReq.setHeader('X-User-ID', req.user.userId);
              proxyReq.setHeader('X-User-Role', req.user.role);
            }
          },
          onProxyRes: (proxyRes, req, res) => {
            // Add CORS headers
            proxyRes.headers['Access-Control-Allow-Origin'] = '*';
            proxyRes.headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization';
          },
          onError: (err, req, res) => {
            logger.error(`Proxy error for ${serviceName}:`, {
              error: err.message,
              requestId: req.requestId,
              target,
            });
            
            res.status(503).json({
              success: false,
              message: `Service ${serviceName} temporarily unavailable`,
              requestId: req.requestId,
            });
          },
        });
        
        return proxy(req, res, next);
      });
    } catch (error) {
      logger.error(`Circuit breaker error for ${serviceName}:`, error);
      res.status(503).json({
        success: false,
        message: `Service ${serviceName} temporarily unavailable`,
        requestId: req.requestId,
      });
    }
  };
};

// Health check endpoint
app.use('/health', healthRoutes);

// Auth service routes (public)
app.use('/api/auth', authLimiter, createServiceProxy('auth', {
  '^/api/auth': ''
}));

// Product service routes (public GET, authenticated POST/PUT/DELETE)
app.use('/api/products', 
  productLimiter,
  authenticateJWTConditional,
  createServiceProxy('product', {
    '^/api/products': '/api/products'
  })
);

// Order service routes (authenticated)
app.use('/api/orders',
  authenticateJWT,
  createServiceProxy('order', {
    '^/api/orders': '/api/orders'
  })
);

// Websocket proxy for real-time features
const { createProxyMiddleware } = require('http-proxy-middleware');

app.use('/ws', createProxyMiddleware({
  target: 'ws://order-service:3003',
  ws: true,
  changeOrigin: true,
}));

// API documentation endpoint
app.get('/api/docs', (req, res) => {
  res.json({
    success: true,
    message: 'Microservices API Gateway',
    version: '1.0.0',
    services: {
      auth: {
        base_url: '/api/auth',
        description: 'Authentication and user management',
        endpoints: [
          'POST /api/auth/register',
          'POST /api/auth/login',
          'POST /api/auth/refresh',
          'GET /api/auth/me',
        ]
      },
      products: {
        base_url: '/api/products',
        description: 'Product catalog management',
        endpoints: [
          'GET /api/products',
          'POST /api/products',
          'GET /api/products/:id',
          'PUT /api/products/:id',
          'DELETE /api/products/:id',
        ]
      },
      orders: {
        base_url: '/api/orders',
        description: 'Order processing and management',
        endpoints: [
          'GET /api/orders',
          'POST /api/orders',
          'GET /api/orders/:id',
          'PUT /api/orders/:id',
        ]
      }
    }
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    path: req.originalUrl,
    requestId: req.requestId,
  });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Gateway error:', {
    error: err.message,
    stack: err.stack,
    requestId: req.requestId,
    url: req.originalUrl,
  });

  res.status(err.status || 500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : err.message,
    requestId: req.requestId,
  });
});

// Graceful shutdown
const gracefulShutdown = () => {
  logger.info('Received shutdown signal, closing gateway...');
  
  server.close(() => {
    logger.info('Gateway server closed');
    redisClient.quit();
    process.exit(0);
  });

  setTimeout(() => {
    logger.error('Could not close gateway gracefully, forcefully shutting down');
    process.exit(1);
  }, 30000);
};

const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`API Gateway started successfully`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
  });
});

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

module.exports = app;
