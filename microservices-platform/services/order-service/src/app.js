const express = require('express');
const { Server } = require('socket.io');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const Redis = require('ioredis');
const Bull = require('bull');
const promMiddleware = require('express-prometheus-middleware');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const orderRoutes = require('./routes/orders');
const healthRoutes = require('./routes/health');
const webhookRoutes = require('./routes/webhooks');
const logger = require('./utils/logger');
const { connectDB } = require('./config/database');
const KafkaService = require('./services/kafkaService');
const OrderService = require('./services/orderService');
const { authenticateToken } = require('./middleware/auth');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3003;

// Socket.IO for real-time updates
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST'],
  },
});

// Redis clients
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
const redisQueue = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

// Bull queues for background processing
const orderProcessingQueue = new Bull('order processing', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  },
});

const notificationQueue = new Bull('notifications', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  },
});

// Initialize services
const kafkaService = new KafkaService();
const orderService = new OrderService(redis, kafkaService, io);

// Prometheus metrics
app.use(promMiddleware({
  metricsPath: '/metrics',
  collectDefaultMetrics: true,
  requestDurationBuckets: [0.1, 0.5, 1, 1.5, 3, 5, 10],
}));

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      connectSrc: ["'self'", "wss:"],
    },
  },
}));

// CORS
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200, // limit each IP to 200 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging with correlation ID
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || uuidv4();
  req.requestId = req.headers['x-request-id'] || uuidv4();
  
  logger.info('Incoming request', {
    method: req.method,
    url: req.originalUrl,
    correlationId: req.correlationId,
    requestId: req.requestId,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
  });
  
  // Add correlation ID to response headers
  res.set('X-Correlation-ID', req.correlationId);
  res.set('X-Request-ID', req.requestId);
  
  next();
});

// Health check (public)
app.use('/health', healthRoutes);

// Webhook endpoints (public with validation)
app.use('/webhooks', webhookRoutes);

// Protected routes
app.use('/api/orders', authenticateToken, orderRoutes);

// WebSocket authentication middleware
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) {
      throw new Error('No token provided');
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.userId;
    socket.userRole = decoded.role;
    next();
  } catch (error) {
    logger.error('WebSocket authentication failed:', error);
    next(new Error('Authentication failed'));
  }
});

// WebSocket connection handling
io.on('connection', (socket) => {
  logger.info('Client connected to WebSocket', {
    socketId: socket.id,
    userId: socket.userId,
  });

  // Join user-specific room for personalized updates
  socket.join(`user_${socket.userId}`);

  // Handle order tracking subscription
  socket.on('track_order', async (orderId) => {
    try {
      const order = await orderService.getOrderById(orderId, socket.userId);
      if (order) {
        socket.join(`order_${orderId}`);
        socket.emit('order_status', {
          orderId,
          status: order.status,
          updates: order.statusHistory,
        });
      }
    } catch (error) {
      logger.error('Error tracking order:', error);
      socket.emit('error', { message: 'Failed to track order' });
    }
  });

  socket.on('disconnect', () => {
    logger.info('Client disconnected from WebSocket', {
      socketId: socket.id,
      userId: socket.userId,
    });
  });
});

// Queue processing for order fulfillment
orderProcessingQueue.process('processOrder', async (job) => {
  const { orderId, correlationId } = job.data;
  
  logger.info('Processing order', { orderId, correlationId });
  
  try {
    await orderService.processOrder(orderId, correlationId);
    
    // Emit real-time update
    io.to(`order_${orderId}`).emit('order_update', {
      orderId,
      status: 'processing',
      timestamp: new Date(),
    });
    
  } catch (error) {
    logger.error('Order processing failed:', { orderId, error: error.message });
    throw error;
  }
});

// Queue processing for notifications
notificationQueue.process('sendNotification', async (job) => {
  const { type, recipient, data } = job.data;
  
  logger.info('Sending notification', { type, recipient });
  
  try {
    // Send notification via external service
    // This could be email, SMS, push notification, etc.
    await sendNotification(type, recipient, data);
  } catch (error) {
    logger.error('Notification sending failed:', error);
    throw error;
  }
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    error: err.message,
    stack: err.stack,
    correlationId: req.correlationId,
    requestId: req.requestId,
    url: req.originalUrl,
    method: req.method,
  });

  const status = err.status || 500;
  const message = process.env.NODE_ENV === 'production' 
    ? 'Internal server error' 
    : err.message;

  res.status(status).json({
    success: false,
    message,
    correlationId: req.correlationId,
    requestId: req.requestId,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    path: req.originalUrl,
    correlationId: req.correlationId,
  });
});

// Graceful shutdown
const gracefulShutdown = async () => {
  logger.info('Received shutdown signal, closing server gracefully...');
  
  try {
    // Close HTTP server
    server.close(() => {
      logger.info('HTTP server closed');
    });

    // Close Socket.IO
    io.close(() => {
      logger.info('Socket.IO server closed');
    });

    // Close database connections
    await mongoose.connection.close();
    logger.info('MongoDB connection closed');

    // Close Redis connections
    redis.disconnect();
    redisQueue.disconnect();
    logger.info('Redis connections closed');

    // Close Kafka connections
    await kafkaService.disconnect();
    logger.info('Kafka connections closed');

    // Close Bull queues
    await orderProcessingQueue.close();
    await notificationQueue.close();
    logger.info('Bull queues closed');

    process.exit(0);
  } catch (error) {
    logger.error('Error during graceful shutdown:', error);
    process.exit(1);
  }
};

// Initialize and start server
async function startServer() {
  try {
    // Connect to databases
    await connectDB();
    logger.info('MongoDB connected');

    // Initialize Kafka
    await kafkaService.connect();
    logger.info('Kafka connected');

    // Set up Kafka consumers
    await kafkaService.setupConsumers();
    logger.info('Kafka consumers set up');

    // Start server
    server.listen(PORT, '0.0.0.0', () => {
      logger.info('Order service started successfully', {
        port: PORT,
        environment: process.env.NODE_ENV || 'development',
        version: process.env.npm_package_version || '1.0.0',
      });
    });

    // Graceful shutdown handlers
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
    process.on('SIGUSR2', gracefulShutdown); // nodemon restart

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Helper function for notifications (placeholder)
async function sendNotification(type, recipient, data) {
  // Implementation would depend on notification service
  // Could be integration with AWS SES, Twilio, Firebase, etc.
  logger.info('Notification sent', { type, recipient, data });
}

// Expose app and io for testing
module.exports = { app, io, startServer };

// Start server if this is the main module
if (require.main === module) {
  startServer();
}
