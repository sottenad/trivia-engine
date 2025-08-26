# Trivia API Documentation

## Overview
This API provides access to multiple-choice trivia questions generated from jService clues. It includes endpoints for retrieving random questions, searching by category, and more.

## Authentication
The API uses two authentication methods:
1. **JWT Authentication** - For user management and API key administration
2. **API Key Authentication** - For accessing trivia endpoints

## Base URL
```
http://localhost:3003/api/v1
```

Note: Legacy endpoints at `/api/{endpoint}` are redirected to `/api/v1/{endpoint}` for backward compatibility.

## Rate Limiting
Each API key has rate limits that can be configured. By default, keys are limited to 100 requests per hour.

## Endpoints

### Health Check
```
GET /health
```
Returns the API status.

### User Management

#### Register User
```
POST /users
```
**Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123"
}
```

#### Login User
```
POST /users/login
```
**Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```
Returns a JWT token for authentication.

#### Get User Profile
```
GET /users/profile
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```

#### Update User Profile
```
PUT /users/profile
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```
**Body:**
```json
{
  "name": "John Updated",
  "email": "updated@example.com",
  "password": "newpassword123"
}
```

### API Key Management

#### Create API Key
```
POST /keys
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```
**Body:**
```json
{
  "name": "My App Key"
}
```

#### Get All API Keys
```
GET /keys
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```

#### Get API Key by ID
```
GET /keys/:id
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```

#### Update API Key
```
PUT /keys/:id
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```
**Body:**
```json
{
  "name": "Updated Key Name",
  "isActive": true
}
```

#### Delete API Key
```
DELETE /keys/:id
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```

#### Update Rate Limit
```
PUT /keys/:id/rate-limit
```
**Headers:**
```
Authorization: Bearer <jwt_token>
```
**Body:**
```json
{
  "limit": 200,
  "window": 3600
}
```
`limit` is the number of requests allowed, `window` is the time period in seconds.

### Trivia Endpoints

#### Get Random Trivia Question
```
GET /trivia/random
```
**Headers:**
```
X-API-Key: <your_api_key>
```
**Query Parameters:**
- `category` (optional): Filter by category name

#### Get Trivia Question by ID
```
GET /trivia/:id
```
**Headers:**
```
X-API-Key: <your_api_key>
```

#### Get Trivia by Category
```
GET /trivia/category/:categoryTitle
```
**Headers:**
```
X-API-Key: <your_api_key>
```
**Query Parameters:**
- `limit` (optional): Number of results to return (default: 10)
- `offset` (optional): Starting position (default: 0)

#### List All Categories
```
GET /trivia/categories
```
**Headers:**
```
X-API-Key: <your_api_key>
```

#### Search Trivia Questions
```
GET /trivia/search
```
**Headers:**
```
X-API-Key: <your_api_key>
```
**Query Parameters:**
- `query`: Search term
- `limit` (optional): Number of results to return (default: 10)
- `offset` (optional): Starting position (default: 0)

## Response Format

All API responses follow a consistent format:

### Success Response
```json
{
  "success": true,
  "data": { ... }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error message"
}
```

## Example Trivia Response

```json
{
  "success": true,
  "trivia": {
    "id": 1,
    "question": "Which of these terms refers to J.K. Rowling's pen name?",
    "options": [
      "pen name",
      "pseudonym",
      "alias",
      "nom de plume"
    ],
    "correctAnswer": "pseudonym",
    "category": "THE PSILENT LETTER",
    "clue": {
      "id": 402901,
      "text": "J.K. Rowling said she chose the pseudonym Robert Galbraith for her crime novels to begin a new phase of her writing",
      "answer": "a pseudonym",
      "category": "THE PSILENT LETTER"
    }
  }
}
```

## Error Codes

- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

## Rate Limit Headers

When rate limiting is in effect, the following headers are included in the response:

- `X-RateLimit-Limit`: Maximum number of requests allowed
- `X-RateLimit-Remaining`: Number of requests remaining in the current window
- `X-RateLimit-Reset`: Time when the rate limit resets (ISO format)
- `Retry-After`: Seconds until requests may be made again (when limit is reached) 