const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { generateApiKey } = require('../utils/authUtils');
const { validationResult } = require('express-validator');

/**
 * @desc    Generate a new API key for the user
 * @route   POST /api/keys
 * @access  Private
 */
const createApiKey = async (req, res, next) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { name } = req.body;
    const userId = req.user.id;

    // Generate a unique API key
    const apiKeyString = generateApiKey();

    // Create API key record
    const apiKey = await prisma.apiKey.create({
      data: {
        name,
        key: apiKeyString,
        userId,
        isActive: true
      }
    });

    // Create default rate limit for the key
    await prisma.rateLimit.create({
      data: {
        apiKeyId: apiKey.id,
        // Default: 100 requests per hour
        limit: 100,
        window: "3600", // 1 hour in seconds as string
        requests: 0,
        resetAt: new Date(Date.now() + 3600 * 1000)
      }
    });

    res.status(201).json({
      success: true,
      apiKey: {
        id: apiKey.id,
        name: apiKey.name,
        key: apiKey.key,
        isActive: apiKey.isActive,
        createdAt: apiKey.createdAt
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all API keys for the user
 * @route   GET /api/keys
 * @access  Private
 */
const getApiKeys = async (req, res, next) => {
  try {
    const userId = req.user.id;

    const apiKeys = await prisma.apiKey.findMany({
      where: { userId },
      include: {
        rateLimits: true
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.json({
      success: true,
      count: apiKeys.length,
      apiKeys: apiKeys.map(key => ({
        id: key.id,
        name: key.name,
        key: key.key,
        isActive: key.isActive,
        lastUsedAt: key.lastUsedAt,
        createdAt: key.createdAt,
        rateLimits: key.rateLimits.map(limit => ({
          id: limit.id,
          limit: limit.limit,
          window: limit.window,
          requests: limit.requests,
          resetAt: limit.resetAt
        }))
      }))
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get API key by ID
 * @route   GET /api/keys/:id
 * @access  Private
 */
const getApiKeyById = async (req, res, next) => {
  try {
    const keyId = parseInt(req.params.id);
    const userId = req.user.id;

    const apiKey = await prisma.apiKey.findUnique({
      where: { 
        id: keyId
      },
      include: {
        rateLimits: true
      }
    });

    // Check if key exists and belongs to the user
    if (!apiKey || apiKey.userId !== userId) {
      res.status(404);
      throw new Error('API key not found');
    }

    res.json({
      success: true,
      apiKey: {
        id: apiKey.id,
        name: apiKey.name,
        key: apiKey.key,
        isActive: apiKey.isActive,
        lastUsedAt: apiKey.lastUsedAt,
        createdAt: apiKey.createdAt,
        rateLimits: apiKey.rateLimits.map(limit => ({
          id: limit.id,
          limit: limit.limit,
          window: limit.window,
          requests: limit.requests,
          resetAt: limit.resetAt
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update API key (name, active status)
 * @route   PUT /api/keys/:id
 * @access  Private
 */
const updateApiKey = async (req, res, next) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const keyId = parseInt(req.params.id);
    const userId = req.user.id;
    const { name, isActive } = req.body;

    // Check if key exists and belongs to the user
    const apiKey = await prisma.apiKey.findUnique({
      where: { id: keyId }
    });

    if (!apiKey || apiKey.userId !== userId) {
      res.status(404);
      throw new Error('API key not found');
    }

    // Prepare update data
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (isActive !== undefined) updateData.isActive = isActive;

    // Update API key
    const updatedKey = await prisma.apiKey.update({
      where: { id: keyId },
      data: updateData,
      include: {
        rateLimits: true
      }
    });

    res.json({
      success: true,
      apiKey: {
        id: updatedKey.id,
        name: updatedKey.name,
        key: updatedKey.key,
        isActive: updatedKey.isActive,
        lastUsedAt: updatedKey.lastUsedAt,
        createdAt: updatedKey.createdAt,
        rateLimits: updatedKey.rateLimits.map(limit => ({
          id: limit.id,
          limit: limit.limit,
          window: limit.window,
          requests: limit.requests,
          resetAt: limit.resetAt
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete API key
 * @route   DELETE /api/keys/:id
 * @access  Private
 */
const deleteApiKey = async (req, res, next) => {
  try {
    const keyId = parseInt(req.params.id);
    const userId = req.user.id;

    // Check if key exists and belongs to the user
    const apiKey = await prisma.apiKey.findUnique({
      where: { id: keyId }
    });

    if (!apiKey || apiKey.userId !== userId) {
      res.status(404);
      throw new Error('API key not found');
    }

    // Delete API key - associated rate limits will be cascaded
    await prisma.apiKey.delete({
      where: { id: keyId }
    });

    res.json({
      success: true,
      message: 'API key deleted'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update rate limit for an API key
 * @route   PUT /api/keys/:id/rate-limit
 * @access  Private
 */
const updateRateLimit = async (req, res, next) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const keyId = parseInt(req.params.id);
    const userId = req.user.id;
    const { limit, window } = req.body;

    // Check if key exists and belongs to the user
    const apiKey = await prisma.apiKey.findUnique({
      where: { id: keyId }
    });

    if (!apiKey || apiKey.userId !== userId) {
      res.status(404);
      throw new Error('API key not found');
    }

    // Find existing rate limit
    const rateLimit = await prisma.rateLimit.findFirst({
      where: { apiKeyId: keyId }
    });

    let updatedLimit;

    if (rateLimit) {
      // Update existing rate limit
      updatedLimit = await prisma.rateLimit.update({
        where: { id: rateLimit.id },
        data: {
          limit,
          window: window.toString(), // Convert to string
          // Reset the counter when updating limit
          requests: 0,
          resetAt: new Date(Date.now() + window * 1000)
        }
      });
    } else {
      // Create new rate limit
      updatedLimit = await prisma.rateLimit.create({
        data: {
          apiKeyId: keyId,
          limit,
          window: window.toString(), // Convert to string
          requests: 0,
          resetAt: new Date(Date.now() + window * 1000)
        }
      });
    }

    res.json({
      success: true,
      rateLimit: {
        id: updatedLimit.id,
        limit: updatedLimit.limit,
        window: updatedLimit.window,
        requests: updatedLimit.requests,
        resetAt: updatedLimit.resetAt
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createApiKey,
  getApiKeys,
  getApiKeyById,
  updateApiKey,
  deleteApiKey,
  updateRateLimit
}; 