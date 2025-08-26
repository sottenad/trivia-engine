const helmet = require('helmet');
const config = require('../../config');

/**
 * Configure comprehensive security headers
 */
const securityHeaders = helmet({
  // Content Security Policy
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  
  // DNS Prefetch Control
  dnsPrefetchControl: {
    allow: false
  },
  
  // Frameguard - Prevent clickjacking
  frameguard: {
    action: 'deny'
  },
  
  // Hide X-Powered-By
  hidePoweredBy: true,
  
  // HSTS - Force HTTPS
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  
  // IE No Open
  ieNoOpen: true,
  
  // No Sniff - Prevent MIME type sniffing
  noSniff: true,
  
  // Origin Agent Cluster
  originAgentCluster: true,
  
  // Permitted Cross Domain Policies
  permittedCrossDomainPolicies: false,
  
  // Referrer Policy
  referrerPolicy: {
    policy: 'strict-origin-when-cross-origin'
  },
  
  // XSS Filter
  xssFilter: true
});

/**
 * Additional security middleware
 */
const additionalSecurity = (req, res, next) => {
  // Remove fingerprinting headers
  res.removeHeader('X-Powered-By');
  res.removeHeader('Server');
  
  // Add additional security headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  
  // Add API-specific headers
  res.setHeader('X-API-Version', 'v1');
  
  // Prevent caching of sensitive data
  if (req.path.includes('/users') || req.path.includes('/keys')) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
  
  next();
};

/**
 * Rate limiting configuration for different endpoints
 */
const createRateLimiter = (windowMs, max, message) => {
  const rateLimit = require('express-rate-limit');
  
  return rateLimit({
    windowMs,
    max,
    message: {
      success: false,
      error: {
        message,
        retryAfter: windowMs / 1000
      }
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      res.status(429).json({
        success: false,
        error: {
          message,
          retryAfter: windowMs / 1000
        }
      });
    }
  });
};

// Different rate limiters for different endpoints
const authRateLimiter = createRateLimiter(
  15 * 60 * 1000, // 15 minutes
  5, // 5 requests per window
  'Too many authentication attempts, please try again later'
);

const apiRateLimiter = createRateLimiter(
  config.rateLimit.globalWindowMs,
  config.rateLimit.globalMax,
  'Too many requests, please try again later'
);

module.exports = {
  securityHeaders,
  additionalSecurity,
  authRateLimiter,
  apiRateLimiter
};