const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');

// Webhook for payment notifications
router.post('/payment', (req, res) => {
  try {
    logger.info('Payment webhook received:', req.body);
    
    // Process payment webhook
    const { orderId, status, transactionId } = req.body;
    
    // Here you would typically update the order status based on payment status
    // and publish events to Kafka
    
    res.status(200).json({ 
      received: true,
      orderId,
      status 
    });
  } catch (error) {
    logger.error('Error processing payment webhook:', error);
    res.status(500).json({ error: 'Failed to process webhook' });
  }
});

// Webhook for shipping notifications
router.post('/shipping', (req, res) => {
  try {
    logger.info('Shipping webhook received:', req.body);
    
    const { orderId, status, trackingNumber } = req.body;
    
    // Process shipping webhook
    
    res.status(200).json({ 
      received: true,
      orderId,
      status 
    });
  } catch (error) {
    logger.error('Error processing shipping webhook:', error);
    res.status(500).json({ error: 'Failed to process webhook' });
  }
});

module.exports = router;
