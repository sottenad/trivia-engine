const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Custom rate limiting middleware for API keys
 */
const apiKeyRateLimit = async (req, res, next) => {
  try {
    if (!req.apiKey) {
      return next();
    }

    const apiKey = req.apiKey;
    const now = new Date();

    // If no rate limits are set for this key, allow the request
    if (!apiKey.rateLimits || apiKey.rateLimits.length === 0) {
      // Use default rate limit if no custom limits
      const defaultLimit = 100; // 100 requests
      const defaultWindow = "3600"; // 1 hour in seconds as string

      // Create a default rate limit for this API key
      await prisma.rateLimit.create({
        data: {
          apiKeyId: apiKey.id,
          limit: defaultLimit,
          window: defaultWindow,
          requests: 1,
          resetAt: new Date(now.getTime() + parseInt(defaultWindow) * 1000)
        }
      });
      
      return next();
    }

    // Check each rate limit for this API key
    for (const rateLimit of apiKey.rateLimits) {
      // If reset time has passed, reset counter
      if (now > rateLimit.resetAt) {
        await prisma.rateLimit.update({
          where: { id: rateLimit.id },
          data: {
            requests: 1,
            resetAt: new Date(now.getTime() + parseInt(rateLimit.window) * 1000)
          }
        });
      } else {
        // Check if limit has been reached
        if (rateLimit.requests >= rateLimit.limit) {
          const resetTimeString = rateLimit.resetAt.toISOString();
          const secondsToReset = Math.ceil((rateLimit.resetAt - now) / 1000);
          
          res.set('X-RateLimit-Limit', rateLimit.limit.toString());
          res.set('X-RateLimit-Remaining', '0');
          res.set('X-RateLimit-Reset', resetTimeString);
          res.set('Retry-After', secondsToReset.toString());
          
          return res.status(429).json({
            success: false,
            message: 'Rate limit exceeded',
            retryAfter: secondsToReset,
            resetAt: resetTimeString
          });
        }

        // Increment request counter
        await prisma.rateLimit.update({
          where: { id: rateLimit.id },
          data: {
            requests: { increment: 1 }
          }
        });

        // Set rate limit headers
        res.set('X-RateLimit-Limit', rateLimit.limit.toString());
        res.set('X-RateLimit-Remaining', (rateLimit.limit - rateLimit.requests - 1).toString());
        res.set('X-RateLimit-Reset', rateLimit.resetAt.toISOString());
      }
    }

    next();
  } catch (error) {
    console.error('Rate limit error:', error);
    next(error);
  }
};

module.exports = { apiKeyRateLimit }; 