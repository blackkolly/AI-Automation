const { Kafka } = require('kafkajs');
const logger = require('../utils/logger');

class KafkaService {
    constructor() {
        this.kafka = new Kafka({
            clientId: 'order-service',
            brokers: [process.env.KAFKA_BROKERS || 'kafka.kafka.svc.cluster.local:9092'],
            retry: {
                initialRetryTime: 100,
                retries: 8
            }
        });
        
        this.producer = this.kafka.producer();
        this.consumer = this.kafka.consumer({ groupId: 'order-service-group' });
        this.isConnected = false;
    }

    async connect() {
        try {
            await this.producer.connect();
            await this.consumer.connect();
            this.isConnected = true;
            logger.info('Kafka connected successfully');
            return true;
        } catch (error) {
            logger.error('Failed to connect to Kafka:', error);
            throw error;
        }
    }

    async disconnect() {
        try {
            await this.producer.disconnect();
            await this.consumer.disconnect();
            this.isConnected = false;
            logger.info('Kafka disconnected');
        } catch (error) {
            logger.error('Error disconnecting from Kafka:', error);
        }
    }

    async setupConsumers() {
        try {
            // Subscribe to order-related topics
            await this.consumer.subscribe({ 
                topics: ['order-events', 'payment-events', 'inventory-events'] 
            });

            // Start consuming messages
            await this.consumer.run({
                eachMessage: async ({ topic, partition, message }) => {
                    try {
                        const messageValue = JSON.parse(message.value.toString());
                        logger.info(`Received message from ${topic}:`, messageValue);
                        
                        switch (topic) {
                            case 'order-events':
                                await this.handleOrderEvent(messageValue);
                                break;
                            case 'payment-events':
                                await this.handlePaymentEvent(messageValue);
                                break;
                            case 'inventory-events':
                                await this.handleInventoryEvent(messageValue);
                                break;
                            default:
                                logger.warn(`Unknown topic: ${topic}`);
                        }
                    } catch (error) {
                        logger.error(`Error processing message from ${topic}:`, error);
                    }
                }
            });

            logger.info('Kafka consumers setup successfully');
        } catch (error) {
            logger.error('Failed to setup Kafka consumers:', error);
            throw error;
        }
    }

    async handleOrderEvent(message) {
        logger.info('Processing order event:', message);
        // Handle order events (create, update, cancel)
    }

    async handlePaymentEvent(message) {
        logger.info('Processing payment event:', message);
        // Handle payment events (success, failure)
    }

    async handleInventoryEvent(message) {
        logger.info('Processing inventory event:', message);
        // Handle inventory events (stock updates)
    }

    async publishMessage(topic, message) {
        try {
            if (!this.isConnected) {
                await this.connect();
            }

            await this.producer.send({
                topic,
                messages: [{
                    key: message.id || Date.now().toString(),
                    value: JSON.stringify(message),
                    timestamp: Date.now()
                }]
            });

            logger.info(`Message published to ${topic}:`, message);
        } catch (error) {
            logger.error(`Failed to publish message to ${topic}:`, error);
            throw error;
        }
    }

    async publishOrderEvent(eventType, orderData) {
        const event = {
            id: orderData.id || Date.now().toString(),
            type: eventType,
            timestamp: new Date().toISOString(),
            data: orderData
        };

        await this.publishMessage('order-events', event);
    }
}

const kafkaService = new KafkaService();
module.exports = kafkaService;
