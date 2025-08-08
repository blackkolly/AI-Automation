// metrics.js - Add this to your Node.js microservices for Prometheus monitoring
const client = require("prom-client");

// Create a Registry to register the metrics
const register = new client.Registry();

// Add default metrics (CPU, memory, event loop lag, etc.)
client.collectDefaultMetrics({ register });

// Custom metrics for microservices
const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code", "service"],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code", "service"],
});

const activeConnections = new client.Gauge({
  name: "active_connections",
  help: "Number of active connections",
  labelNames: ["service"],
});

const databaseConnections = new client.Gauge({
  name: "database_connections_active",
  help: "Number of active database connections",
  labelNames: ["service", "database"],
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeConnections);
register.registerMetric(databaseConnections);

// Middleware for Express.js to collect HTTP metrics
const metricsMiddleware = (serviceName) => {
  return (req, res, next) => {
    const start = Date.now();

    res.on("finish", () => {
      const duration = (Date.now() - start) / 1000;
      const route = req.route ? req.route.path : req.path;

      httpRequestDuration
        .labels(req.method, route, res.statusCode.toString(), serviceName)
        .observe(duration);

      httpRequestsTotal
        .labels(req.method, route, res.statusCode.toString(), serviceName)
        .inc();
    });

    next();
  };
};

// Function to start metrics server
const startMetricsServer = (port = 9090) => {
  const express = require("express");
  const metricsApp = express();

  metricsApp.get("/metrics", async (req, res) => {
    try {
      res.set("Content-Type", register.contentType);
      const metrics = await register.metrics();
      res.end(metrics);
    } catch (error) {
      res.status(500).end(error);
    }
  });

  metricsApp.get("/health", (req, res) => {
    res
      .status(200)
      .json({ status: "healthy", timestamp: new Date().toISOString() });
  });

  metricsApp.listen(port, () => {
    console.log(`📊 Metrics server listening on port ${port}`);
  });
};

// Helper functions for custom metrics
const incrementActiveConnections = (serviceName) => {
  activeConnections.labels(serviceName).inc();
};

const decrementActiveConnections = (serviceName) => {
  activeConnections.labels(serviceName).dec();
};

const setDatabaseConnections = (serviceName, database, count) => {
  databaseConnections.labels(serviceName, database).set(count);
};

module.exports = {
  register,
  metricsMiddleware,
  startMetricsServer,
  incrementActiveConnections,
  decrementActiveConnections,
  setDatabaseConnections,
  // Export individual metrics for custom use
  httpRequestDuration,
  httpRequestsTotal,
  activeConnections,
  databaseConnections,
};

/* 
USAGE EXAMPLE in your main app.js:

const express = require('express');
const { metricsMiddleware, startMetricsServer } = require('./metrics');

const app = express();
const serviceName = process.env.SERVICE_NAME || 'unknown-service';

// Add metrics middleware
app.use(metricsMiddleware(serviceName));

// Your existing routes...
app.get('/', (req, res) => {
  res.json({ service: serviceName, status: 'running' });
});

// Start main application
app.listen(3000, () => {
  console.log(`🚀 ${serviceName} listening on port 3000`);
});

// Start metrics server on separate port
if (process.env.ENABLE_METRICS === 'true') {
  startMetricsServer(parseInt(process.env.METRICS_PORT) || 9090);
}
*/
