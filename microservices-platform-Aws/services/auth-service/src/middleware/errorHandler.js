const errorHandler = (error, req, res, next) => {
  const logger = req.app.locals.logger;

  // Log the error
  if (logger) {
    logger.error({
      error: error.message,
      stack: error.stack,
      path: req.path,
      method: req.method,
      ip: req.ip,
      timestamp: new Date().toISOString(),
    });
  }

  // Handle specific error types
  if (error.name === "ValidationError") {
    return res.status(400).json({
      error: "Validation Error",
      message: error.message,
      details: error.details || [],
    });
  }

  if (error.name === "JsonWebTokenError") {
    return res.status(401).json({
      error: "Invalid Token",
      message: "The provided token is invalid",
    });
  }

  if (error.name === "TokenExpiredError") {
    return res.status(401).json({
      error: "Token Expired",
      message: "The provided token has expired",
    });
  }

  if (error.code === "23505") {
    // PostgreSQL unique constraint violation
    return res.status(409).json({
      error: "Duplicate Entry",
      message: "A record with this information already exists",
    });
  }

  if (error.code === "23503") {
    // PostgreSQL foreign key violation
    return res.status(400).json({
      error: "Reference Error",
      message: "Referenced record does not exist",
    });
  }

  // Default error response
  const statusCode = error.statusCode || error.status || 500;

  res.status(statusCode).json({
    error: "Internal Server Error",
    message:
      process.env.NODE_ENV === "development"
        ? error.message
        : "An unexpected error occurred",
    ...(process.env.NODE_ENV === "development" && { stack: error.stack }),
  });
};

module.exports = errorHandler;
