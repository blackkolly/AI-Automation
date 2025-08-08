const opentracing = require("opentracing");

function createTracingMiddleware(tracer) {
  return (req, res, next) => {
    // Extract parent span context from headers
    const parentSpanContext = tracer.extract(
      opentracing.FORMAT_HTTP_HEADERS,
      req.headers
    );

    // Create span for this request
    const span = tracer.startSpan(
      `${req.method} ${req.route?.path || req.path}`,
      {
        childOf: parentSpanContext,
        tags: {
          [opentracing.Tags.HTTP_METHOD]: req.method,
          [opentracing.Tags.HTTP_URL]: req.originalUrl,
          [opentracing.Tags.SPAN_KIND]: opentracing.Tags.SPAN_KIND_RPC_SERVER,
          "service.name": process.env.SERVICE_NAME || "microservice",
          "user.id": req.headers["x-user-id"] || "anonymous",
          "user.email": req.headers["x-user-email"] || "unknown",
        },
      }
    );

    // Add span to request for downstream use
    req.span = span;
    req.tracer = tracer;

    // Prepare trace headers for outgoing requests
    const traceHeaders = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, traceHeaders);
    req.traceHeaders = traceHeaders;

    // Override res.json to capture response
    const originalJson = res.json;
    res.json = function (body) {
      span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);

      if (res.statusCode >= 400) {
        span.setTag(opentracing.Tags.ERROR, true);
        span.log({
          event: "error",
          "error.object": body,
          "error.kind": res.statusCode >= 500 ? "server_error" : "client_error",
        });
      }

      span.log({
        event: "response",
        response_body: typeof body === "object" ? JSON.stringify(body) : body,
      });
      span.finish();
      return originalJson.call(this, body);
    };

    // Handle errors
    const originalSend = res.send;
    res.send = function (body) {
      if (!res.headersSent) {
        span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);
        if (res.statusCode >= 400) {
          span.setTag(opentracing.Tags.ERROR, true);
          span.log({ event: "error", response_body: body });
        }
        span.finish();
      }
      return originalSend.call(this, body);
    };

    next();
  };
}

// Helper function to trace database operations
function traceDbOperation(
  tracer,
  parentSpan,
  operation,
  collection,
  query = {}
) {
  const span = tracer.startSpan(`db.${operation}`, {
    childOf: parentSpan,
    tags: {
      [opentracing.Tags.DB_TYPE]: "mongodb",
      [opentracing.Tags.DB_STATEMENT]: JSON.stringify(query),
      "db.collection.name": collection,
      "db.operation": operation,
    },
  });

  return {
    span,
    finish: (error = null, result = null) => {
      if (error) {
        span.setTag(opentracing.Tags.ERROR, true);
        span.log({ event: "error", "error.object": error.message });
      }

      if (result) {
        span.log({
          event: "db_result",
          result_count: Array.isArray(result) ? result.length : 1,
        });
      }

      span.finish();
    },
  };
}

// Helper function to trace Kafka operations
function traceKafkaOperation(
  tracer,
  parentSpan,
  operation,
  topic,
  message = null
) {
  const span = tracer.startSpan(`kafka.${operation}`, {
    childOf: parentSpan,
    tags: {
      "messaging.system": "kafka",
      "messaging.destination": topic,
      "messaging.operation": operation,
      "messaging.destination_kind": "topic",
    },
  });

  if (message) {
    span.setTag("messaging.message_id", message.key || "no-key");
    span.log({
      event: "kafka_message",
      message: JSON.stringify(message.value),
    });
  }

  return {
    span,
    finish: (error = null, result = null) => {
      if (error) {
        span.setTag(opentracing.Tags.ERROR, true);
        span.log({ event: "error", "error.object": error.message });
      }

      if (result) {
        span.log({
          event: "kafka_result",
          partition: result.partition,
          offset: result.offset,
        });
      }

      span.finish();
    },
  };
}

// Helper function to trace HTTP calls to other services
function traceHttpCall(tracer, parentSpan, method, url, options = {}) {
  const span = tracer.startSpan(`${method.toUpperCase()} ${url}`, {
    childOf: parentSpan,
    tags: {
      [opentracing.Tags.HTTP_METHOD]: method.toUpperCase(),
      [opentracing.Tags.HTTP_URL]: url,
      [opentracing.Tags.SPAN_KIND]: opentracing.Tags.SPAN_KIND_RPC_CLIENT,
    },
  });

  // Inject trace headers
  const headers = options.headers || {};
  tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, headers);

  return {
    span,
    headers,
    finish: (error = null, response = null) => {
      if (error) {
        span.setTag(opentracing.Tags.ERROR, true);
        span.setTag(opentracing.Tags.HTTP_STATUS_CODE, error.status || 0);
        span.log({ event: "error", "error.object": error.message });
      }

      if (response) {
        span.setTag(opentracing.Tags.HTTP_STATUS_CODE, response.status);
        if (response.status >= 400) {
          span.setTag(opentracing.Tags.ERROR, true);
        }
      }

      span.finish();
    },
  };
}

module.exports = {
  createTracingMiddleware,
  traceDbOperation,
  traceKafkaOperation,
  traceHttpCall,
};
