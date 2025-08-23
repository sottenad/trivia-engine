const express = require('express');
const router = express.Router();
const { check } = require('express-validator');
const {
  createApiKey,
  getApiKeys,
  getApiKeyById,
  updateApiKey,
  deleteApiKey,
  updateRateLimit
} = require('../controllers/apiKeyController');
const { protect } = require('../middleware/authMiddleware');

// Input validation rules
const apiKeyCreateValidation = [
  check('name', 'Name is required').not().isEmpty()
];

const apiKeyUpdateValidation = [
  check('name', 'Name must not be empty').optional().not().isEmpty(),
  check('isActive', 'isActive must be a boolean').optional().isBoolean()
];

const rateLimitValidation = [
  check('limit', 'Limit must be a positive integer').isInt({ min: 1 }),
  check('window', 'Window must be a positive integer (seconds)').isInt({ min: 1 })
];

// @route   POST /api/keys
// @desc    Create a new API key
// @access  Private
router.post('/', protect, apiKeyCreateValidation, createApiKey);

// @route   GET /api/keys
// @desc    Get all API keys for the user
// @access  Private
router.get('/', protect, getApiKeys);

// @route   GET /api/keys/:id
// @desc    Get API key by ID
// @access  Private
router.get('/:id', protect, getApiKeyById);

// @route   PUT /api/keys/:id
// @desc    Update API key (name, active status)
// @access  Private
router.put('/:id', protect, apiKeyUpdateValidation, updateApiKey);

// @route   DELETE /api/keys/:id
// @desc    Delete API key
// @access  Private
router.delete('/:id', protect, deleteApiKey);

// @route   PUT /api/keys/:id/rate-limit
// @desc    Update rate limit for an API key
// @access  Private
router.put('/:id/rate-limit', protect, rateLimitValidation, updateRateLimit);

module.exports = router; 