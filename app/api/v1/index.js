const express = require('express');
const router = express.Router();

// Import existing routes
const userRoutes = require('../routes/userRoutes');
const apiKeyRoutes = require('../routes/apiKeyRoutes');
const triviaRoutes = require('../routes/triviaRoutes');

// API v1 routes
router.use('/users', userRoutes);
router.use('/keys', apiKeyRoutes);
router.use('/trivia', triviaRoutes);

// Version info endpoint
router.get('/', (req, res) => {
  res.json({
    success: true,
    data: {
      version: 'v1',
      endpoints: {
        users: '/api/v1/users',
        apiKeys: '/api/v1/keys',
        trivia: '/api/v1/trivia'
      }
    }
  });
});

module.exports = router;