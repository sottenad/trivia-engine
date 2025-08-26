const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['DATABASE_URL', 'JWT_SECRET'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  console.error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
  console.error('Please check your .env file');
  process.exit(1);
}

// Configuration object
const config = {
  // Server configuration
  port: parseInt(process.env.PORT || '3003', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  
  // Database configuration
  database: {
    url: process.env.DATABASE_URL,
    // Connection pool settings
    connectionLimit: parseInt(process.env.DB_CONNECTION_LIMIT || '10', 10),
  },
  
  // JWT configuration
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '90d',
  },
  
  // API Key configuration
  apiKey: {
    saltRounds: parseInt(process.env.API_KEY_SALT_ROUNDS || '32', 10),
    defaultRateLimit: {
      requests: parseInt(process.env.DEFAULT_RATE_LIMIT_REQUESTS || '100', 10),
      windowSeconds: parseInt(process.env.DEFAULT_RATE_LIMIT_WINDOW || '3600', 10),
    },
  },
  
  // Security configuration
  security: {
    bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '10', 10),
    corsOrigin: process.env.CORS_ORIGIN || '*',
    trustedProxies: process.env.TRUSTED_PROXIES ? process.env.TRUSTED_PROXIES.split(',') : [],
  },
  
  // Logging configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.LOG_FORMAT || 'json',
  },
  
  // Cache configuration (for future Redis implementation)
  cache: {
    enabled: process.env.CACHE_ENABLED === 'true',
    ttl: parseInt(process.env.CACHE_TTL || '3600', 10),
    redisUrl: process.env.REDIS_URL,
  },
  
  // Rate limiting configuration
  rateLimit: {
    globalEnabled: process.env.GLOBAL_RATE_LIMIT_ENABLED !== 'false',
    globalMax: parseInt(process.env.GLOBAL_RATE_LIMIT_MAX || '1000', 10),
    globalWindowMs: parseInt(process.env.GLOBAL_RATE_LIMIT_WINDOW_MS || '900000', 10), // 15 minutes
  },
};

// Validate numeric values
const validateNumeric = (value, name, min = 0) => {
  if (isNaN(value) || value < min) {
    throw new Error(`Invalid configuration: ${name} must be a number >= ${min}`);
  }
};

// Perform validation
validateNumeric(config.port, 'port', 1);
validateNumeric(config.database.connectionLimit, 'database.connectionLimit', 1);
validateNumeric(config.security.bcryptRounds, 'security.bcryptRounds', 1);
validateNumeric(config.apiKey.defaultRateLimit.requests, 'apiKey.defaultRateLimit.requests', 1);
validateNumeric(config.apiKey.defaultRateLimit.windowSeconds, 'apiKey.defaultRateLimit.windowSeconds', 1);

module.exports = config;