// Node.js OpenTelemetry Instrumentation Example
// This file shows how to instrument a Node.js application with OpenTelemetry

const { NodeSDK } = require("@opentelemetry/sdk-node");
const {
  getNodeAutoInstrumentations,
} = require("@opentelemetry/auto-instrumentations-node");
const { JaegerExporter } = require("@opentelemetry/exporter-jaeger");
const { Resource } = require("@opentelemetry/resources");
const {
  SemanticResourceAttributes,
} = require("@opentelemetry/semantic-conventions");

// Configure the Jaeger exporter
const jaegerExporter = new JaegerExporter({
  endpoint: "http://jaeger-collector:14268/api/traces",
});

// Initialize the SDK
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: "user-service",
    [SemanticResourceAttributes.SERVICE_VERSION]: "1.0.0",
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: "production",
  }),
  traceExporter: jaegerExporter,
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-fs": {
        enabled: false, // Disable file system instrumentation to reduce noise
      },
    }),
  ],
});

// Start the SDK
sdk.start();

console.log("OpenTelemetry started successfully");

// Export for manual instrumentation
const { trace, context } = require("@opentelemetry/api");

module.exports = {
  tracer: trace.getTracer("user-service"),
  context,
};

/* 
Usage in application code:

const { tracer } = require('./tracing');
const express = require('express');
const app = express();

app.get('/users/:id', async (req, res) => {
  const span = tracer.startSpan('get_user');
  
  try {
    span.setAttributes({
      'user.id': req.params.id,
      'http.method': req.method,
      'http.url': req.url,
    });
    
    const user = await getUserById(req.params.id);
    
    span.setAttributes({
      'user.name': user.name,
      'user.email': user.email,
    });
    
    res.json(user);
  } catch (error) {
    span.recordException(error);
    span.setStatus({
      code: trace.SpanStatusCode.ERROR,
      message: error.message,
    });
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    span.end();
  }
});

// Database operation with tracing
async function getUserById(id) {
  return tracer.startActiveSpan('database.get_user', async (span) => {
    try {
      span.setAttributes({
        'db.system': 'mongodb',
        'db.operation': 'find',
        'db.collection': 'users',
        'db.query': `{"_id": "${id}"}`,
      });
      
      const user = await db.collection('users').findOne({ _id: id });
      
      if (!user) {
        span.setAttributes({ 'user.found': false });
        throw new Error('User not found');
      }
      
      span.setAttributes({ 'user.found': true });
      return user;
    } catch (error) {
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
*/
