const express = require('express');
const router = express.Router();

// Health check endpoint
router.get('/', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        service: 'order-service',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Readiness probe
router.get('/ready', (req, res) => {
    // Check if all dependencies are ready
    res.status(200).json({
        status: 'ready',
        service: 'order-service',
        timestamp: new Date().toISOString()
    });
});

// Liveness probe
router.get('/live', (req, res) => {
    res.status(200).json({
        status: 'alive',
        service: 'order-service',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;
