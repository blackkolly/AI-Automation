const { initTracer } = require("jaeger-client");

function initJaegerTracer(serviceName = "microservice") {
  const config = {
    serviceName: serviceName,
    sampler: {
      type: process.env.JAEGER_SAMPLER_TYPE || "const",
      param: parseFloat(process.env.JAEGER_SAMPLER_PARAM) || 1,
    },
    reporter: {
      logSpans: process.env.NODE_ENV === "development",
      agentHost:
        process.env.JAEGER_AGENT_HOST ||
        "jaeger-agent.observability.svc.cluster.local",
      agentPort: parseInt(process.env.JAEGER_AGENT_PORT) || 6832,
      collectorEndpoint:
        process.env.JAEGER_COLLECTOR_URL ||
        "http://jaeger-collector.observability.svc.cluster.local:14268/api/traces",
    },
  };

  const options = {
    tags: {
      [`${serviceName}.version`]: process.env.npm_package_version || "1.0.0",
      "deployment.environment": process.env.NODE_ENV || "development",
      "service.namespace": "microservices",
      "kubernetes.namespace":
        process.env.KUBERNETES_NAMESPACE || "microservices",
      "kubernetes.pod": process.env.HOSTNAME || "unknown",
    },
    logger: {
      info: (msg) => {
        if (process.env.NODE_ENV !== "production") {
          console.log("JAEGER INFO:", msg);
        }
      },
      error: (msg) => console.error("JAEGER ERROR:", msg),
    },
  };

  return initTracer(config, options);
}

module.exports = { initJaegerTracer };
