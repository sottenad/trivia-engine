const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const config = require('../../config');

/**
 * Generate a JWT token
 * @param {number} id - User ID
 * @returns {string} JWT token
 */
const generateToken = (id) => {
  return jwt.sign({ id }, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn
  });
};

/**
 * Generate a refresh token
 * @param {number} id - User ID
 * @returns {string} Refresh token
 */
const generateRefreshToken = (id) => {
  return jwt.sign({ id, type: 'refresh' }, config.jwt.secret, {
    expiresIn: config.jwt.refreshExpiresIn
  });
};

/**
 * Hash a password
 * @param {string} password - Plain text password
 * @returns {Promise<string>} Hashed password
 */
const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(config.security.bcryptRounds);
  return await bcrypt.hash(password, salt);
};

/**
 * Compare password with hashed password
 * @param {string} enteredPassword - Plain text password
 * @param {string} hashedPassword - Hashed password
 * @returns {Promise<boolean>} True if passwords match
 */
const comparePassword = async (enteredPassword, hashedPassword) => {
  return await bcrypt.compare(enteredPassword, hashedPassword);
};

/**
 * Generate a secure API key
 * @returns {string} API key
 */
const generateApiKey = () => {
  // Generate a secure random API key using crypto
  const buffer = crypto.randomBytes(config.apiKey.saltRounds);
  const apiKey = buffer.toString('base64url');
  
  // Add a prefix to make it identifiable
  return `sk_${apiKey}`;
};

/**
 * Validate password complexity
 * @param {string} password - Password to validate
 * @returns {object} Validation result with isValid and errors
 */
const validatePasswordComplexity = (password) => {
  const errors = [];
  
  if (password.length < 8) {
    errors.push('Password must be at least 8 characters long');
  }
  
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  
  if (!/[0-9]/.test(password)) {
    errors.push('Password must contain at least one number');
  }
  
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    errors.push('Password must contain at least one special character');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
};

module.exports = {
  generateToken,
  generateRefreshToken,
  hashPassword,
  comparePassword,
  generateApiKey,
  validatePasswordComplexity
}; 