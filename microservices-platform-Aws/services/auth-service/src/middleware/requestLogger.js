const winston = require("winston");

const requestLogger = (req, res, next) => {
  const logger =
    req.app.locals.logger ||
    winston.createLogger({
      transports: [new winston.transports.Console()],
    });

  const start = Date.now();

  // Log request
  logger.info({
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get("User-Agent"),
    timestamp: new Date().toISOString(),
  });

  // Override res.end to log response
  const originalEnd = res.end;
  res.end = function (...args) {
    const duration = Date.now() - start;

    logger.info({
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString(),
    });

    originalEnd.apply(res, args);
  };

  next();
};

module.exports = requestLogger;
