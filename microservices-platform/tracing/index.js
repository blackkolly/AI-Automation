/**
 * Jaeger Distributed Tracing Module
 *
 * This module provides a centralized configuration and utilities for
 * distributed tracing across all microservices using Jaeger.
 *
 * Usage:
 * const { initJaegerTracer, createTracingMiddleware } = require('./tracing');
 *
 * const tracer = initJaegerTracer('your-service-name');
 * app.use(createTracingMiddleware(tracer));
 */

const { initJaegerTracer } = require("./configs/jaeger-config");
const {
  createTracingMiddleware,
  traceDbOperation,
  traceKafkaOperation,
  traceHttpCall,
} = require("./middleware/tracing-middleware");

// Export all tracing utilities
module.exports = {
  // Core tracer initialization
  initJaegerTracer,

  // Express middleware
  createTracingMiddleware,

  // Helper functions for common operations
  traceDbOperation,
  traceKafkaOperation,
  traceHttpCall,

  // Constants for common tags
  TracingTags: {
    SERVICE_NAME: "service.name",
    SERVICE_VERSION: "service.version",
    USER_ID: "user.id",
    USER_EMAIL: "user.email",
    REQUEST_ID: "request.id",
    ERROR_TYPE: "error.type",
    DB_OPERATION: "db.operation",
    DB_COLLECTION: "db.collection.name",
    KAFKA_TOPIC: "messaging.destination",
    KAFKA_OPERATION: "messaging.operation",
  },

  // Environment configuration helper
  getTracingConfig: () => ({
    jaegerAgentHost:
      process.env.JAEGER_AGENT_HOST ||
      "jaeger-agent.observability.svc.cluster.local",
    jaegerAgentPort: parseInt(process.env.JAEGER_AGENT_PORT) || 6832,
    jaegerCollectorUrl:
      process.env.JAEGER_COLLECTOR_URL ||
      "http://jaeger-collector.observability.svc.cluster.local:14268/api/traces",
    samplerType: process.env.JAEGER_SAMPLER_TYPE || "const",
    samplerParam: parseFloat(process.env.JAEGER_SAMPLER_PARAM) || 1,
    serviceName: process.env.SERVICE_NAME || "unknown-service",
    serviceVersion: process.env.SERVICE_VERSION || "1.0.0",
    environment: process.env.NODE_ENV || "development",
  }),
};
