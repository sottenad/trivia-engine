const express = require('express');
const router = express.Router();
const { check } = require('express-validator');
const {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  getUsers,
  deleteUser
} = require('../controllers/userController');
const { protect, admin } = require('../middleware/authMiddleware');
const asyncHandler = require('../utils/asyncHandler');
const { authRateLimiter } = require('../middleware/security');
const { handleValidationErrors } = require('../middleware/sanitization');

// Input validation rules
const registerValidation = [
  check('name', 'Name is required').not().isEmpty().trim(),
  check('email', 'Please include a valid email').isEmail().normalizeEmail(),
  check('password', 'Password must be at least 8 characters').isLength({ min: 8 })
];

const loginValidation = [
  check('email', 'Please include a valid email').isEmail(),
  check('password', 'Password is required').exists()
];

const updateValidation = [
  check('name', 'Name must not be empty').optional().not().isEmpty().trim(),
  check('email', 'Please include a valid email').optional().isEmail().normalizeEmail(),
  check('password', 'Password must be at least 8 characters').optional().isLength({ min: 8 })
];

// @route   POST /api/users
// @desc    Register a new user
// @access  Public
router.post('/', authRateLimiter, registerValidation, handleValidationErrors, asyncHandler(registerUser));

// @route   POST /api/users/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', authRateLimiter, loginValidation, handleValidationErrors, asyncHandler(loginUser));

// @route   GET /api/users/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', protect, asyncHandler(getUserProfile));

// @route   PUT /api/users/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', protect, updateValidation, handleValidationErrors, asyncHandler(updateUserProfile));

// @route   GET /api/users
// @desc    Get all users
// @access  Private/Admin
router.get('/', protect, admin, asyncHandler(getUsers));

// @route   DELETE /api/users/:id
// @desc    Delete user
// @access  Private/Admin
router.delete('/:id', protect, admin, asyncHandler(deleteUser));

module.exports = router; 