const express = require('express');
const router = express.Router();
const {
  getRandomTriviaQuestion,
  getTriviaQuestionById,
  getTriviaByCategory,
  getCategories,
  searchTrivia
} = require('../controllers/triviaController');
const { verifyApiKey } = require('../middleware/authMiddleware');
const { apiKeyRateLimit } = require('../middleware/rateLimitMiddleware');

// Apply API key middleware to all trivia routes
router.use(verifyApiKey);
router.use(apiKeyRateLimit);

// @route   GET /api/trivia/random
// @desc    Get a random trivia question
// @access  Private (requires API key)
router.get('/random', getRandomTriviaQuestion);

// @route   GET /api/trivia/categories
// @desc    Get all categories with trivia questions
// @access  Private (requires API key)
router.get('/categories', getCategories);

// @route   GET /api/trivia/category/:categoryTitle
// @desc    Get trivia questions by category
// @access  Private (requires API key)
router.get('/category/:categoryTitle', getTriviaByCategory);

// @route   GET /api/trivia/search
// @desc    Search trivia questions
// @access  Private (requires API key)
router.get('/search', searchTrivia);

// @route   GET /api/trivia/:id
// @desc    Get trivia question by ID
// @access  Private (requires API key)
router.get('/:id', getTriviaQuestionById);

module.exports = router; 