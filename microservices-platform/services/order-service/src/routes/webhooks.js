const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');

// Payment webhook
router.post('/payment', async (req, res) => {
    try {
        const paymentData = req.body;
        logger.info('Received payment webhook:', paymentData);
        
        // Process payment notification
        // This would typically update order status based on payment result
        
        res.status(200).json({ message: 'Payment webhook processed successfully' });
    } catch (error) {
        logger.error('Error processing payment webhook:', error);
        res.status(500).json({ error: 'Failed to process payment webhook' });
    }
});

// Inventory webhook
router.post('/inventory', async (req, res) => {
    try {
        const inventoryData = req.body;
        logger.info('Received inventory webhook:', inventoryData);
        
        // Process inventory notification
        // This would typically handle stock level changes
        
        res.status(200).json({ message: 'Inventory webhook processed successfully' });
    } catch (error) {
        logger.error('Error processing inventory webhook:', error);
        res.status(500).json({ error: 'Failed to process inventory webhook' });
    }
});

// Generic webhook handler
router.post('/:service', async (req, res) => {
    try {
        const { service } = req.params;
        const webhookData = req.body;
        
        logger.info(`Received webhook from ${service}:`, webhookData);
        
        res.status(200).json({ 
            message: `Webhook from ${service} processed successfully` 
        });
    } catch (error) {
        logger.error('Error processing webhook:', error);
        res.status(500).json({ error: 'Failed to process webhook' });
    }
});

module.exports = router;
