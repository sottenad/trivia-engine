/**
 * Request logging middleware
 * Logs API requests with useful information while keeping output concise
 */
const requestLogger = (req, res, next) => {
  const start = Date.now();
  const requestInfo = {
    method: req.method,
    path: req.path,
    requestId: req.id,
  };

  // Log request body for POST/PUT/PATCH requests (excluding sensitive data)
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
    const bodyToLog = { ...req.body };
    
    // Remove sensitive fields from logs
    if (bodyToLog.password) bodyToLog.password = '[REDACTED]';
    if (bodyToLog.apiKey) bodyToLog.apiKey = '[REDACTED]';
    if (bodyToLog.token) bodyToLog.token = '[REDACTED]';
    
    // Only log if body has content
    if (Object.keys(bodyToLog).length > 0) {
      requestInfo.body = bodyToLog;
    }
  }

  // Log query parameters if present
  if (Object.keys(req.query).length > 0) {
    requestInfo.query = req.query;
  }

  // Log incoming request
  console.log(`→ ${req.method} ${req.path}`, requestInfo);

  // Override res.json to log response
  const originalJson = res.json.bind(res);
  res.json = function(data) {
    const duration = Date.now() - start;
    const statusCode = res.statusCode;
    const statusEmoji = statusCode >= 200 && statusCode < 300 ? '✓' : '✗';
    
    // Create response summary
    const responseInfo = {
      requestId: req.id,
      duration: `${duration}ms`,
      status: statusCode,
    };

    // Log data summary for successful responses
    if (statusCode >= 200 && statusCode < 300 && data) {
      if (data.data) {
        // API response format
        if (data.data.trivia) {
          responseInfo.data = `trivia question (id: ${data.data.trivia.id})`;
        } else if (data.data.categories && Array.isArray(data.data.categories)) {
          responseInfo.data = `${data.data.categories.length} categories`;
        } else if (data.data.triviaList && Array.isArray(data.data.triviaList)) {
          responseInfo.data = `${data.data.triviaList.length} trivia questions`;
        } else if (data.data.user) {
          responseInfo.data = `user (id: ${data.data.user.id})`;
        } else if (data.data.apiKey) {
          responseInfo.data = `API key created`;
        }
      }
    } else if (data && data.error) {
      // Error response
      responseInfo.error = data.error.message || 'Unknown error';
    }

    console.log(`${statusEmoji} ${req.method} ${req.path} [${statusCode}]`, responseInfo);
    
    return originalJson(data);
  };

  next();
};

module.exports = requestLogger;