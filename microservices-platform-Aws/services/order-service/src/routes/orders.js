const express = require("express");
const router = express.Router();
const orderService = require("../services/orderService");
const logger = require("../utils/logger");

// Get all orders for a user
router.get("/", async (req, res) => {
  try {
    const userId = req.user.id;
    const orders = await orderService.getOrdersByUserId(userId);
    res.json({ orders });
  } catch (error) {
    logger.error("Error fetching orders:", error);
    res.status(500).json({ error: "Failed to fetch orders" });
  }
});

// Get order by ID
router.get("/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;
    const order = await orderService.getOrderById(orderId, userId);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    res.json({ order });
  } catch (error) {
    logger.error("Error fetching order:", error);
    res.status(500).json({ error: "Failed to fetch order" });
  }
});

// Create new order
router.post("/", async (req, res) => {
  try {
    const userId = req.user.id;
    const orderData = { ...req.body, userId };

    const order = await orderService.createOrder(orderData);
    res.status(201).json({ order });
  } catch (error) {
    logger.error("Error creating order:", error);
    res.status(500).json({ error: "Failed to create order" });
  }
});

// Update order status
router.patch("/:orderId/status", async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;
    const userId = req.user.id;

    const order = await orderService.updateOrderStatus(orderId, status, userId);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    res.json({ order });
  } catch (error) {
    logger.error("Error updating order status:", error);
    res.status(500).json({ error: "Failed to update order status" });
  }
});

// Cancel order
router.delete("/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;
    const userId = req.user.id;

    const result = await orderService.cancelOrder(orderId, userId);

    if (!result) {
      return res.status(404).json({ error: "Order not found" });
    }

    res.json({ message: "Order cancelled successfully" });
  } catch (error) {
    logger.error("Error cancelling order:", error);
    res.status(500).json({ error: "Failed to cancel order" });
  }
});

module.exports = router;
