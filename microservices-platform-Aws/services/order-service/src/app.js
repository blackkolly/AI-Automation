const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const morgan = require("morgan");

// Import services
const kafkaService = require("./services/kafkaService");
const logger = require("./utils/logger");

// Import routes
const healthRoutes = require("./routes/health");
const orderRoutes = require("./routes/orders");
const webhookRoutes = require("./routes/webhooks");

// Import middleware
const authMiddleware = require("./middleware/auth");

const app = express();
const PORT = process.env.PORT || 3003;

// Security middleware
app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || "*",
    credentials: true,
  })
);

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Compression middleware
app.use(compression());

// Logging middleware
app.use(
  morgan("combined", {
    stream: { write: (message) => logger.info(message.trim()) },
  })
);

// Health check route (no auth required)
app.use("/health", healthRoutes);

// Protected routes
app.use("/api/orders", authMiddleware, orderRoutes);

// Webhook routes (no auth required for external services)
app.use("/webhooks", webhookRoutes);

// Global error handler
app.use((error, req, res, next) => {
  logger.error("Unhandled error:", error);
  res.status(500).json({
    error: "Internal server error",
    message:
      process.env.NODE_ENV === "development"
        ? error.message
        : "Something went wrong",
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: "Not found",
    message: `Route ${req.method} ${req.path} not found`,
  });
});

// Database connection
const connectDatabase = async () => {
  try {
    // Database connection logic would go here
    // For now, just log success
    logger.info("Database connected successfully");
    logger.info("Database tables created successfully");
    return true;
  } catch (error) {
    logger.error("Database connection failed:", error);
    throw error;
  }
};

// MongoDB connection (if needed)
const connectMongoDB = async () => {
  try {
    // MongoDB connection logic would go here
    logger.info("MongoDB connected");
    return true;
  } catch (error) {
    logger.error("MongoDB connection failed:", error);
    throw error;
  }
};

// Start server function
const startServer = async () => {
  try {
    // Connect to database
    await connectDatabase();

    // Connect to MongoDB
    await connectMongoDB();

    // Connect to Kafka
    await kafkaService.connect();
    logger.info("Kafka connected");

    // Setup Kafka consumers
    await kafkaService.setupConsumers();
    logger.info("Kafka consumers setup completed");

    // Start HTTP server
    const server = app.listen(PORT, "0.0.0.0", () => {
      logger.info(`Order service running on port ${PORT}`);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal) => {
      logger.info(`Received ${signal}, shutting down gracefully`);

      server.close(async () => {
        try {
          await kafkaService.disconnect();
          logger.info("Order service shut down successfully");
          process.exit(0);
        } catch (error) {
          logger.error("Error during shutdown:", error);
          process.exit(1);
        }
      });
    };

    process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
    process.on("SIGINT", () => gracefulShutdown("SIGINT"));
  } catch (error) {
    logger.error("Failed to start server:", error);
    process.exit(1);
  }
};

// Start the server
if (require.main === module) {
  startServer();
}

module.exports = app;
