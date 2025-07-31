const { getPool } = require('../config/database');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

class OrderService {
  static async getUserOrders(userId) {
    const pool = getPool();
    try {
      const result = await pool.query(
        'SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC',
        [userId]
      );
      return result.rows;
    } catch (error) {
      logger.error('Error fetching user orders:', error);
      throw error;
    }
  }

  static async getOrder(orderId, userId) {
    const pool = getPool();
    try {
      const result = await pool.query(
        'SELECT * FROM orders WHERE id = $1 AND user_id = $2',
        [orderId, userId]
      );
      
      if (result.rows.length === 0) {
        return null;
      }

      const order = result.rows[0];
      
      // Get order items
      const itemsResult = await pool.query(
        'SELECT * FROM order_items WHERE order_id = $1',
        [orderId]
      );
      
      order.items = itemsResult.rows;
      return order;
    } catch (error) {
      logger.error('Error fetching order:', error);
      throw error;
    }
  }

  static async createOrder(orderData) {
    const pool = getPool();
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      const orderId = uuidv4();
      const {
        userId,
        items,
        totalAmount,
        shippingAddress,
        billingAddress,
        paymentMethod
      } = orderData;

      // Insert order
      const orderResult = await client.query(`
        INSERT INTO orders (id, user_id, items, total_amount, shipping_address, billing_address, payment_method)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
      `, [
        orderId,
        userId,
        JSON.stringify(items),
        totalAmount,
        JSON.stringify(shippingAddress),
        JSON.stringify(billingAddress),
        paymentMethod
      ]);

      // Insert order items
      for (const item of items) {
        await client.query(`
          INSERT INTO order_items (order_id, product_id, quantity, price)
          VALUES ($1, $2, $3, $4)
        `, [orderId, item.productId, item.quantity, item.price]);
      }

      await client.query('COMMIT');
      
      const order = orderResult.rows[0];
      logger.info(`Order created successfully: ${orderId}`);
      
      return order;
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Error creating order:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  static async updateOrderStatus(orderId, status, userId) {
    const pool = getPool();
    try {
      const result = await pool.query(`
        UPDATE orders 
        SET status = $1, updated_at = CURRENT_TIMESTAMP 
        WHERE id = $2 AND user_id = $3
        RETURNING *
      `, [status, orderId, userId]);
      
      return result.rows.length > 0 ? result.rows[0] : null;
    } catch (error) {
      logger.error('Error updating order status:', error);
      throw error;
    }
  }

  static async cancelOrder(orderId, userId) {
    const pool = getPool();
    try {
      const result = await pool.query(`
        UPDATE orders 
        SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP 
        WHERE id = $1 AND user_id = $2 AND status IN ('pending', 'confirmed')
        RETURNING *
      `, [orderId, userId]);
      
      return result.rows.length > 0;
    } catch (error) {
      logger.error('Error cancelling order:', error);
      throw error;
    }
  }
}

module.exports = OrderService;
