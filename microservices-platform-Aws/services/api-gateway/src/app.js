const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { createProxyMiddleware } = require("http-proxy-middleware");
const jwt = require("jsonwebtoken");
const axios = require("axios");
const winston = require("winston");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configure logger
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "api-gateway.log" }),
  ],
});

// Security middleware
app.use(helmet());
app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
    ],
    credentials: true,
  })
);

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: "Too many requests from this IP, please try again later.",
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || "your-secret-key"
    );
    req.user = decoded;
    next();
  } catch (error) {
    logger.error("Token verification failed:", error);
    return res.status(403).json({ error: "Invalid token" });
  }
};

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "api-gateway",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || "1.0.0",
  });
});

// Service URLs
const services = {
  auth:
    process.env.AUTH_SERVICE_URL ||
    "http://auth-service.microservices.svc.cluster.local:3001",
  order:
    process.env.ORDER_SERVICE_URL ||
    "http://order-service.microservices.svc.cluster.local:3003",
  product:
    process.env.PRODUCT_SERVICE_URL ||
    "http://product-service.microservices.svc.cluster.local:8080",
};

// Auth service routes (public)
app.use(
  "/api/auth",
  createProxyMiddleware({
    target: services.auth,
    changeOrigin: true,
    pathRewrite: {
      "^/api/auth": "",
    },
    onError: (err, req, res) => {
      logger.error("Auth service proxy error:", err);
      res.status(503).json({ error: "Auth service unavailable" });
    },
  })
);

// Product service routes (public for browsing, protected for management)
app.use(
  "/api/products",
  createProxyMiddleware({
    target: services.product,
    changeOrigin: true,
    pathRewrite: {
      "^/api/products": "/api/products",
    },
    onError: (err, req, res) => {
      logger.error("Product service proxy error:", err);
      res.status(503).json({ error: "Product service unavailable" });
    },
  })
);

// Order service routes (protected)
app.use(
  "/api/orders",
  authenticateToken,
  createProxyMiddleware({
    target: services.order,
    changeOrigin: true,
    pathRewrite: {
      "^/api/orders": "",
    },
    onProxyReq: (proxyReq, req, res) => {
      // Forward user information to order service
      proxyReq.setHeader("X-User-ID", req.user.id);
      proxyReq.setHeader("X-User-Email", req.user.email);
    },
    onError: (err, req, res) => {
      logger.error("Order service proxy error:", err);
      res.status(503).json({ error: "Order service unavailable" });
    },
  })
);

// Service status endpoint
app.get("/api/status", async (req, res) => {
  const serviceStatus = {};

  for (const [name, url] of Object.entries(services)) {
    try {
      const response = await axios.get(`${url}/health`, { timeout: 5000 });
      serviceStatus[name] = {
        status: "healthy",
        responseTime: response.headers["x-response-time"] || "N/A",
        version: response.data.version || "Unknown",
      };
    } catch (error) {
      serviceStatus[name] = {
        status: "unhealthy",
        error: error.message,
      };
    }
  }

  const overallHealth = Object.values(serviceStatus).every(
    (service) => service.status === "healthy"
  );

  res.status(overallHealth ? 200 : 503).json({
    gateway: {
      status: "healthy",
      timestamp: new Date().toISOString(),
    },
    services: serviceStatus,
    overall: overallHealth ? "healthy" : "degraded",
  });
});

// Catch-all for unmatched routes
app.use("*", (req, res) => {
  res.status(404).json({
    error: "Route not found",
    path: req.originalUrl,
    availableRoutes: [
      "/api/auth",
      "/api/products",
      "/api/orders",
      "/health",
      "/api/status",
    ],
  });
});

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

// Graceful shutdown
process.on("SIGTERM", () => {
  logger.info("SIGTERM received, shutting down gracefully");
  process.exit(0);
});

process.on("SIGINT", () => {
  logger.info("SIGINT received, shutting down gracefully");
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  logger.info(`🚀 API Gateway running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
  logger.info("Available routes:");
  logger.info("  GET  /health - Health check");
  logger.info("  GET  /api/status - Service status");
  logger.info("  POST /api/auth/* - Authentication routes");
  logger.info("  GET  /api/products/* - Product routes");
  logger.info("  *    /api/orders/* - Order routes (authenticated)");
});

module.exports = app;
