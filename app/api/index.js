const express = require('express');
const cors = require('cors');
const config = require('../config');
const { prisma } = require('../config/database');

// Route imports
const v1Routes = require('./v1');

// Middleware imports
const { errorHandler, notFound } = require('./middleware/errorMiddleware');
const requestId = require('./middleware/requestId');
const requestLogger = require('./middleware/requestLogger');
const { sanitizeRequest } = require('./middleware/sanitization');
const { securityHeaders, additionalSecurity, apiRateLimiter } = require('./middleware/security');

// Initialize Express app
const app = express();

// Set port from config
const PORT = config.port;

// Security middleware
app.use(securityHeaders);
app.use(additionalSecurity);
app.use(cors({
  origin: config.security.corsOrigin,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key', 'X-Request-ID'],
  maxAge: 86400 // 24 hours
}));

// Request ID middleware
app.use(requestId);

// Global rate limiting
if (config.rateLimit.globalEnabled) {
  app.use(apiRateLimiter);
}

// Input sanitization
app.use(sanitizeRequest);

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Request logging middleware (after body parser)
app.use(requestLogger);

// Mount v1 routes
app.use('/api/v1', v1Routes);

// Legacy route support (redirect to v1)
app.use('/api/users', (req, res) => res.redirect(301, `/api/v1/users${req.url}`));
app.use('/api/keys', (req, res) => res.redirect(301, `/api/v1/keys${req.url}`));
app.use('/api/trivia', (req, res) => res.redirect(301, `/api/v1/trivia${req.url}`));

// Health check route (available at both paths)
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    data: {
      status: 'healthy',
      timestamp: new Date(),
      version: 'v1'
    }
  });
});

app.get('/api/v1/health', (req, res) => {
  res.json({
    success: true,
    data: {
      status: 'healthy',
      timestamp: new Date(),
      version: 'v1'
    }
  });
});

// API info route
app.get('/api', (req, res) => {
  res.json({
    success: true,
    data: {
      message: 'Trivia Engine API',
      currentVersion: 'v1',
      availableVersions: ['v1'],
      documentation: '/api/v1'
    }
  });
});

// Catch 404 routes
app.use(notFound);

// Error handling middleware (single handler)
app.use(errorHandler);

// Catch unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.log('Unhandled Rejection at:', promise, 'reason:', reason);
  // Application continues running despite unhandled promise rejections
});

// Catch uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Log the error but keep the application running
  // In a production environment, you might want to gracefully restart the app
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Graceful shutdown handling
process.on('SIGTERM', shutDown);
process.on('SIGINT', shutDown);

async function shutDown() {
  console.log('Received shutdown signal');
  
  // Close server
  server.close(async () => {
    console.log('Closed express server');
    
    // Disconnect Prisma
    await prisma.$disconnect();
    console.log('Disconnected Prisma client');
    
    process.exit(0);
  });
  
  // Force close after 5 seconds
  setTimeout(() => {
    console.error('Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 5000);
}

module.exports = { app, prisma }; 