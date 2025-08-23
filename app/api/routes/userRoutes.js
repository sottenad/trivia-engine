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

// Input validation rules
const registerValidation = [
  check('name', 'Name is required').not().isEmpty(),
  check('email', 'Please include a valid email').isEmail(),
  check('password', 'Password must be 6 or more characters').isLength({ min: 6 })
];

const loginValidation = [
  check('email', 'Please include a valid email').isEmail(),
  check('password', 'Password is required').exists()
];

const updateValidation = [
  check('name', 'Name must not be empty').optional().not().isEmpty(),
  check('email', 'Please include a valid email').optional().isEmail(),
  check('password', 'Password must be 6 or more characters').optional().isLength({ min: 6 })
];

// @route   POST /api/users
// @desc    Register a new user
// @access  Public
router.post('/', registerValidation, asyncHandler(registerUser));

// @route   POST /api/users/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', loginValidation, asyncHandler(loginUser));

// @route   GET /api/users/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', protect, asyncHandler(getUserProfile));

// @route   PUT /api/users/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', protect, updateValidation, asyncHandler(updateUserProfile));

// @route   GET /api/users
// @desc    Get all users
// @access  Private/Admin
router.get('/', protect, admin, asyncHandler(getUsers));

// @route   DELETE /api/users/:id
// @desc    Delete user
// @access  Private/Admin
router.delete('/:id', protect, admin, asyncHandler(deleteUser));

module.exports = router; 