const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const asyncHandler = require('express-async-handler');

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key';

/**
 * Middleware to protect routes - verify JWT token
 */
const protect = asyncHandler(async (req, res, next) => {
  try {
    let token;
    
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    } else if (req.cookies && req.cookies.token) {
      token = req.cookies.token;
    }
    
    if (!token) {
      return res.status(401).json({ 
        success: false, 
        error: 'Not authorized, no token provided' 
      });
    }
    
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = await prisma.user.findUnique({
        where: { id: decoded.id },
        select: {
          id: true,
          name: true,
          email: true,
          isAdmin: true
        }
      });

      if (!req.user) {
        res.status(401);
        throw new Error('User not found');
      }

      next();
    } catch (error) {
      console.error('Token verification error:', error);
      return res.status(401).json({ 
        success: false, 
        error: 'Not authorized, invalid token' 
      });
    }
  } catch (error) {
    console.error('Auth middleware error:', error);
    return res.status(500).json({ 
      success: false, 
      error: 'Authentication error' 
    });
  }
});

/**
 * Middleware to ensure user is an admin
 */
const admin = (req, res, next) => {
  if (req.user && req.user.isAdmin) {
    next();
  } else {
    res.status(403);
    throw new Error('Not authorized as admin');
  }
};

/**
 * Middleware to verify API key
 */
// ... existing code ...

/**
 * Middleware to verify API key
 */
const verifyApiKey = async (req, res, next) => {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({
      success: false,
      message: 'API key is required. Please include an X-API-Key header.'
    });
  }

  try {
    // Find API key in database
    const key = await prisma.apiKey.findUnique({
      where: { key: apiKey },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            isAdmin: true
          }
        },
        rateLimits: true
      }
    });

    if (!key) {
      return res.status(401).json({
        success: false,
        message: 'Invalid API key.'
      });
    }

    if (!key.isActive) {
      return res.status(403).json({
        success: false,
        message: 'API key is not active.'
      });
    }

    // Set key and user information in the request
    req.apiKey = key;
    req.user = key.user;

    // Update lastUsedAt
    await prisma.apiKey.update({
      where: { id: key.id },
      data: { lastUsedAt: new Date() }
    });

    next();
  } catch (error) {
    console.error(`API Key Error: ${error.message}`);
    return res.status(500).json({
      success: false,
      message: 'Server error while validating API key.'
    });
  }
};

module.exports = { protect, admin, verifyApiKey }; 