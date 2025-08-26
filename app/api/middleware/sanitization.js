const { validationResult } = require('express-validator');
const xss = require('xss');

/**
 * Sanitize string inputs to prevent XSS attacks
 * @param {string} input - Input to sanitize
 * @returns {string} Sanitized input
 */
const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;
  
  // Remove any script tags and dangerous HTML
  return xss(input, {
    whiteList: {}, // No HTML tags allowed
    stripIgnoreTag: true,
    stripIgnoreTagBody: ['script']
  }).trim();
};

/**
 * Recursively sanitize object properties
 * @param {Object} obj - Object to sanitize
 * @returns {Object} Sanitized object
 */
const sanitizeObject = (obj) => {
  if (!obj || typeof obj !== 'object') return obj;
  
  const sanitized = Array.isArray(obj) ? [] : {};
  
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      if (typeof obj[key] === 'string') {
        sanitized[key] = sanitizeInput(obj[key]);
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        sanitized[key] = sanitizeObject(obj[key]);
      } else {
        sanitized[key] = obj[key];
      }
    }
  }
  
  return sanitized;
};

/**
 * Middleware to sanitize request body, query, and params
 */
const sanitizeRequest = (req, res, next) => {
  // Sanitize body
  if (req.body) {
    req.body = sanitizeObject(req.body);
  }
  
  // Sanitize query parameters
  if (req.query) {
    req.query = sanitizeObject(req.query);
  }
  
  // Sanitize route parameters
  if (req.params) {
    req.params = sanitizeObject(req.params);
  }
  
  next();
};

/**
 * Enhanced validation error handler
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const formattedErrors = errors.array().map(error => ({
      field: error.param,
      message: error.msg,
      value: error.value
    }));
    
    return res.status(400).json({
      success: false,
      error: {
        message: 'Validation failed',
        details: formattedErrors
      }
    });
  }
  
  next();
};

module.exports = {
  sanitizeInput,
  sanitizeObject,
  sanitizeRequest,
  handleValidationErrors
};