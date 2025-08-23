const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Route imports
const userRoutes = require('./routes/userRoutes');
const apiKeyRoutes = require('./routes/apiKeyRoutes');
const triviaRoutes = require('./routes/triviaRoutes');

// Middleware imports
const { errorHandler } = require('./middleware/errorMiddleware');

// Initialize Express app
const app = express();
const prisma = new PrismaClient();

// Set port from environment or default
const PORT = process.env.PORT || 3003;

// Security middleware
app.use(helmet());
app.use(cors());

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Mount routes
app.use('/api/users', userRoutes);
app.use('/api/keys', apiKeyRoutes);
app.use('/api/trivia', triviaRoutes);

// Health check route
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'API is running',
    timestamp: new Date()
  });
});

// Catch 404 routes
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Error handling middleware
app.use(errorHandler);

// Add global error handling middleware at the end of your middleware chain
app.use((err, req, res, next) => {
  console.error('Global error handler caught:', err.stack);
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';
  res.status(statusCode).json({
    success: false,
    error: message,
    stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack
  });
});

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