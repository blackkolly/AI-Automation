// jaeger-config.js - Universal Jaeger configuration for all microservices
const initJaegerTracer = require("jaeger-client").initTracer;

function initTracer(serviceName) {
  const config = {
    serviceName: serviceName,
    sampler: {
      type: process.env.JAEGER_SAMPLER_TYPE || "const",
      param: parseFloat(process.env.JAEGER_SAMPLER_PARAM || "1"),
    },
    reporter: {
      // Use your Jaeger collector endpoint
      endpoint:
        process.env.JAEGER_ENDPOINT ||
        "http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:14268/api/traces",
      logSpans: process.env.NODE_ENV !== "production",
      agentHost: process.env.JAEGER_AGENT_HOST,
      agentPort: process.env.JAEGER_AGENT_PORT
        ? parseInt(process.env.JAEGER_AGENT_PORT)
        : undefined,
    },
  };

  const options = {
    tags: {
      "service.version": process.env.SERVICE_VERSION || "1.0.0",
      "service.environment": process.env.NODE_ENV || "development",
      "kubernetes.namespace":
        process.env.KUBERNETES_NAMESPACE || "microservices",
      "kubernetes.pod": process.env.HOSTNAME || "unknown",
    },
    logger: {
      info: function logInfo(msg) {
        if (process.env.NODE_ENV !== "production") {
          console.log("JAEGER INFO:", msg);
        }
      },
      error: function logError(msg) {
        console.error("JAEGER ERROR:", msg);
      },
    },
  };

  return initJaegerTracer(config, options);
}

module.exports = initTracer;
