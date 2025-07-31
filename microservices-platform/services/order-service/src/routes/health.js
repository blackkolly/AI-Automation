const express = require('express');
const router = express.Router();

// Health check endpoint
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'order-service',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Readiness check
router.get('/ready', (req, res) => {
  // Add any readiness checks here (database connection, etc.)
  res.status(200).json({
    status: 'ready',
    service: 'order-service',
    timestamp: new Date().toISOString()
  });
});

// Liveness check
router.get('/live', (req, res) => {
  res.status(200).json({
    status: 'alive',
    service: 'order-service',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
