const { prisma } = require('../../config/database');
const { generateToken, hashPassword, comparePassword, validatePasswordComplexity } = require('../utils/authUtils');
const { ApiError } = require('../middleware/errorMiddleware');
const { validationResult } = require('express-validator');
const asyncHandler = require('../utils/asyncHandler');

/**
 * @desc    Register a new user
 * @route   POST /api/users
 * @access  Public
 */
const registerUser = asyncHandler(async (req, res, next) => {
  // Check for validation errors
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ApiError(400, 'Validation error', errors.array());
  }

  const { name, email, password } = req.body;

  // Validate password complexity
  const passwordValidation = validatePasswordComplexity(password);
  if (!passwordValidation.isValid) {
    throw new ApiError(400, passwordValidation.errors.join(', '));
  }

  // Check if user already exists
  const userExists = await prisma.user.findUnique({
    where: { email }
  });

  if (userExists) {
    throw new ApiError(409, 'User already exists');
  }

  // Create user
  const user = await prisma.user.create({
    data: {
      name,
      email,
      password: await hashPassword(password),
      isAdmin: false
    }
  });

  // Generate token
  const token = generateToken(user.id);
  
  res.status(201).json({
    success: true,
    data: {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        isAdmin: user.isAdmin
      },
      token
    }
  });
});

/**
 * @desc    Authenticate user & get token
 * @route   POST /api/users/login
 * @access  Public
 */
const loginUser = async (req, res, next) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ApiError(400, 'Validation error', errors.array());
    }

    const { email, password } = req.body;

    // Find user by email
    const user = await prisma.user.findUnique({
      where: { email }
    });

    // Check if user exists and password matches
    if (user && (await comparePassword(password, user.password))) {
      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            isAdmin: user.isAdmin
          },
          token: generateToken(user.id)
        }
      });
    } else {
      throw new ApiError(401, 'Invalid email or password');
    }
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get user profile
 * @route   GET /api/users/profile
 * @access  Private
 */
const getUserProfile = async (req, res, next) => {
  try {
    // User is already attached to req by auth middleware
    const user = req.user;

    if (user) {
      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            isAdmin: user.isAdmin
          }
        }
      });
    } else {
      throw new ApiError(404, 'User not found');
    }
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update user profile
 * @route   PUT /api/users/profile
 * @access  Private
 */
const updateUserProfile = async (req, res, next) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      throw new ApiError(400, 'Validation error', errors.array());
    }

    // Get user from database
    const user = await prisma.user.findUnique({
      where: { id: req.user.id }
    });

    if (!user) {
      throw new ApiError(404, 'User not found');
    }

    // Update user fields
    const { name, email, password } = req.body;

    // Prepare update data
    const updateData = {};
    if (name) updateData.name = name;
    if (email) updateData.email = email;
    if (password) {
      // Validate password complexity
      const passwordValidation = validatePasswordComplexity(password);
      if (!passwordValidation.isValid) {
        throw new ApiError(400, passwordValidation.errors.join(', '));
      }
      updateData.password = await hashPassword(password);
    }

    // Update user
    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: updateData
    });

    res.json({
      success: true,
      data: {
        user: {
          id: updatedUser.id,
          name: updatedUser.name,
          email: updatedUser.email,
          isAdmin: updatedUser.isAdmin
        },
        token: generateToken(updatedUser.id)
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all users (admin only)
 * @route   GET /api/users
 * @access  Private/Admin
 */
const getUsers = async (req, res, next) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        isAdmin: true,
        createdAt: true
      }
    });

    res.json({
      success: true,
      data: {
        count: users.length,
        users
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete user (admin only)
 * @route   DELETE /api/users/:id
 * @access  Private/Admin
 */
const deleteUser = async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(req.params.id) }
    });

    if (!user) {
      throw new ApiError(404, 'User not found');
    }

    // Don't allow admin to delete themselves
    if (user.id === req.user.id) {
      throw new ApiError(400, 'Cannot delete your own account');
    }

    await prisma.user.delete({
      where: { id: parseInt(req.params.id) }
    });

    res.json({ success: true, data: { message: 'User removed' } });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  getUsers,
  deleteUser
}; 