const opentracing = require("opentracing");

function createTracingMiddleware(tracer, serviceName) {
  return function tracingMiddleware(req, res, next) {
    // Extract trace context from incoming headers
    const wireCtx = tracer.extract(
      opentracing.FORMAT_HTTP_HEADERS,
      req.headers
    );

    // Create new span for this request
    const span = tracer.startSpan(`${req.method} ${req.path}`, {
      childOf: wireCtx,
    });

    // Add standard HTTP tags
    span.setTag(opentracing.Tags.HTTP_METHOD, req.method);
    span.setTag(opentracing.Tags.HTTP_URL, req.url);
    span.setTag(
      opentracing.Tags.SPAN_KIND,
      opentracing.Tags.SPAN_KIND_RPC_SERVER
    );
    span.setTag("service.name", serviceName);
    span.setTag("http.user_agent", req.get("User-Agent") || "");

    // Add custom business tags if available
    if (req.headers["user-id"]) {
      span.setTag("user.id", req.headers["user-id"]);
    }
    if (req.headers["request-id"]) {
      span.setTag("request.id", req.headers["request-id"]);
    }

    // Store span and create headers for downstream services
    req.span = span;
    req.traceHeaders = {};
    tracer.inject(span, opentracing.FORMAT_HTTP_HEADERS, req.traceHeaders);

    // Log request start
    span.log({
      event: "request_start",
      method: req.method,
      url: req.url,
      user_agent: req.get("User-Agent"),
    });

    // Finish span when response is sent
    res.on("finish", () => {
      span.setTag(opentracing.Tags.HTTP_STATUS_CODE, res.statusCode);

      // Mark errors
      if (res.statusCode >= 400) {
        span.setTag(opentracing.Tags.ERROR, true);
        span.setTag("error.status_code", res.statusCode);
      }

      // Log response
      span.log({
        event: "request_finish",
        status_code: res.statusCode,
        response_size: res.get("Content-Length") || 0,
      });

      span.finish();
    });

    // Handle aborted requests
    req.on("aborted", () => {
      span.setTag(opentracing.Tags.ERROR, true);
      span.setTag("error.type", "request_aborted");
      span.log({ event: "request_aborted" });
      span.finish();
    });

    next();
  };
}

// Helper function to create child spans
function createChildSpan(parentSpan, operationName, tags = {}) {
  const tracer = opentracing.globalTracer();
  const childSpan = tracer.startSpan(operationName, {
    childOf: parentSpan,
  });

  // Add provided tags
  Object.entries(tags).forEach(([key, value]) => {
    childSpan.setTag(key, value);
  });

  return childSpan;
}

// Helper function for HTTP calls
function traceHttpCall(parentSpan, method, url, headers = {}) {
  const httpSpan = createChildSpan(parentSpan, `http.${method.toLowerCase()}`, {
    "http.method": method,
    "http.url": url,
    "span.kind": "client",
  });

  // Inject trace context into headers
  const tracer = opentracing.globalTracer();
  tracer.inject(httpSpan, opentracing.FORMAT_HTTP_HEADERS, headers);

  return httpSpan;
}

// Helper function for database operations
function traceDatabase(parentSpan, operation, query, params = {}) {
  const dbSpan = createChildSpan(parentSpan, `db.${operation}`, {
    "db.type": "postgresql",
    "db.statement": query,
    "span.kind": "client",
  });

  // Add parameters as tags (be careful not to log sensitive data)
  Object.entries(params).forEach(([key, value]) => {
    if (
      !key.toLowerCase().includes("password") &&
      !key.toLowerCase().includes("token")
    ) {
      dbSpan.setTag(`db.param.${key}`, value);
    }
  });

  return dbSpan;
}

// Helper function for Kafka operations
function traceKafkaOperation(parentSpan, operation, topic, message = {}) {
  const kafkaSpan = createChildSpan(parentSpan, `kafka.${operation}`, {
    "messaging.system": "kafka",
    "messaging.destination": topic,
    "messaging.operation": operation,
    "span.kind": "producer",
  });

  // Add message metadata
  if (message.key) {
    kafkaSpan.setTag("messaging.message_id", message.key);
  }

  return kafkaSpan;
}

module.exports = {
  createTracingMiddleware,
  createChildSpan,
  traceHttpCall,
  traceDatabase,
  traceKafkaOperation,
};
