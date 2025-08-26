# Logging Improvements

## Overview

The logging has been updated to be less verbose while providing useful information about API requests and MCP tool calls.

## Changes Made

### 1. Reduced Prisma Logging
- **File**: `/app/config/database.js`
- **Change**: Changed Prisma log level from `['query', 'error', 'warn']` to `['error', 'warn']`
- **Result**: No more SQL query logs cluttering the output

### 2. API Request Logging
- **File**: `/app/api/middleware/requestLogger.js` (new)
- **Features**:
  - Logs incoming requests with method, path, and request ID
  - Shows request body for POST/PUT/PATCH (with sensitive fields redacted)
  - Logs query parameters when present
  - Shows response status, duration, and data summary
  - Uses emojis for quick visual feedback (✓ for success, ✗ for errors)

Example output:
```
→ GET /api/v1/trivia/random {"method":"GET","path":"/api/v1/trivia/random","requestId":"abc-123"}
✓ GET /api/v1/trivia/random [200] {"requestId":"abc-123","duration":"45ms","status":200,"data":"trivia question (id: 42)"}
```

### 3. MCP Server Tool Call Logging
- **File**: `/mcp/index.ts`
- **Features**:
  - Logs all tool calls with timestamp
  - Shows tool name and parameters (sensitive data redacted)
  - Provides response summaries instead of full data
  - Includes error messages for failed calls
  - Logs to stderr (visible in Claude Desktop logs)

Example output:
```
✓ MCP Tool: get_random_trivia {"timestamp":"2024-01-10T12:00:00.000Z","tool":"get_random_trivia","params":{"category":"Science"},"response":"trivia question (id: 42)"}
```

## Benefits

1. **Less Noise**: No more SQL queries flooding the logs
2. **Better Visibility**: Clear indication of what's happening with requests and tool calls
3. **Security**: Sensitive data (passwords, API keys, tokens) are automatically redacted
4. **Performance Tracking**: Request durations help identify slow endpoints
5. **Debugging**: Request IDs help trace issues through the system
6. **Tool Usage Insights**: See which MCP tools are being used and how

## Configuration

No additional configuration needed. The logging middleware is automatically applied to all API routes.