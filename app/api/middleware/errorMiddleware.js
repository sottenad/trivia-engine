const config = require('../../config');

/**
 * Custom error class for API errors
 */
class ApiError extends Error {
  constructor(statusCode, message, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Error handling middleware
 */
const errorHandler = (err, req, res, next) => {
  let statusCode = err.statusCode || res.statusCode || 500;
  if (statusCode === 200) statusCode = 500; // Default to 500 if status is still 200
  
  // Log error details
  const errorDetails = {
    message: err.message,
    statusCode,
    timestamp: new Date().toISOString(),
    path: req.path,
    method: req.method,
    ip: req.ip,
    requestId: req.id || 'no-request-id'
  };
  
  if (config.nodeEnv !== 'production') {
    errorDetails.stack = err.stack;
  }
  
  console.error('API Error:', errorDetails);
  
  // Prepare error response
  const errorResponse = {
    success: false,
    error: {
      message: err.message,
      statusCode,
      timestamp: errorDetails.timestamp,
      path: errorDetails.path,
      requestId: errorDetails.requestId
    }
  };
  
  // Add stack trace in development
  if (config.nodeEnv !== 'production' && err.stack) {
    errorResponse.error.stack = err.stack;
  }
  
  // Handle specific error types
  if (err.name === 'ValidationError') {
    errorResponse.error.message = 'Validation Error';
    errorResponse.error.details = err.details || err.message;
  } else if (err.name === 'UnauthorizedError') {
    statusCode = 401;
    errorResponse.error.message = 'Unauthorized';
  } else if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    errorResponse.error.message = 'Invalid token';
  } else if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    errorResponse.error.message = 'Token expired';
  } else if (err.code === 'P2002') {
    // Prisma unique constraint error
    statusCode = 409;
    errorResponse.error.message = 'Resource already exists';
  } else if (err.code === 'P2025') {
    // Prisma record not found error
    statusCode = 404;
    errorResponse.error.message = 'Resource not found';
  }
  
  res.status(statusCode).json(errorResponse);
};

/**
 * Not found handler
 */
const notFound = (req, res, next) => {
  const error = new ApiError(404, `Not found - ${req.originalUrl}`);
  next(error);
};

module.exports = { 
  errorHandler, 
  notFound,
  ApiError 
}; 