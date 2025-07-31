const { Kafka } = require('kafkajs');
const logger = require('../utils/logger');

class KafkaService {
  constructor() {
    this.kafka = new Kafka({
      clientId: 'order-service',
      brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
    });
    
    this.producer = this.kafka.producer();
    this.consumer = this.kafka.consumer({ groupId: 'order-service-group' });
  }

  async connect() {
    try {
      await this.producer.connect();
      await this.consumer.connect();
      logger.info('Kafka connected successfully');
    } catch (error) {
      logger.error('Error connecting to Kafka:', error);
      throw error;
    }
  }

  async disconnect() {
    try {
      await this.producer.disconnect();
      await this.consumer.disconnect();
      logger.info('Kafka disconnected');
    } catch (error) {
      logger.error('Error disconnecting from Kafka:', error);
      throw error;
    }
  }

  async publishOrderEvent(eventType, orderData) {
    try {
      await this.producer.send({
        topic: 'order-events',
        messages: [
          {
            key: orderData.id,
            value: JSON.stringify({
              eventType,
              orderId: orderData.id,
              userId: orderData.user_id,
              data: orderData,
              timestamp: new Date().toISOString()
            })
          }
        ]
      });
      
      logger.info(`Order event published: ${eventType} for order ${orderData.id}`);
    } catch (error) {
      logger.error('Error publishing order event:', error);
      throw error;
    }
  }

  async subscribeToEvents() {
    try {
      await this.consumer.subscribe({ topic: 'payment-events' });
      await this.consumer.subscribe({ topic: 'inventory-events' });
      
      await this.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            const event = JSON.parse(message.value.toString());
            logger.info(`Received event from ${topic}:`, event);
            
            // Process different event types
            switch (topic) {
              case 'payment-events':
                await this.handlePaymentEvent(event);
                break;
              case 'inventory-events':
                await this.handleInventoryEvent(event);
                break;
              default:
                logger.warn(`Unknown topic: ${topic}`);
            }
          } catch (error) {
            logger.error('Error processing Kafka message:', error);
          }
        },
      });
    } catch (error) {
      logger.error('Error subscribing to Kafka events:', error);
      throw error;
    }
  }

  async handlePaymentEvent(event) {
    // Handle payment related events
    logger.info('Processing payment event:', event);
  }

  async handleInventoryEvent(event) {
    // Handle inventory related events
    logger.info('Processing inventory event:', event);
  }
}

module.exports = KafkaService;
