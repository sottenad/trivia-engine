// Type definitions for Trivia Engine API

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    message: string;
    statusCode?: number;
    details?: any;
  };
  message?: string;
}

// User types
export interface User {
  id: number;
  name: string;
  email: string;
  isAdmin: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface UserWithToken extends User {
  token: string;
}

// API Key types
export interface ApiKey {
  id: number;
  name: string;
  key: string;
  isActive: boolean;
  lastUsedAt?: string;
  createdAt: string;
  updatedAt?: string;
  rateLimits?: RateLimit[];
}

export interface RateLimit {
  id: number;
  limit: number;
  window: number; // in seconds
  requests: number;
  resetAt: string;
}

// Trivia types
export interface TriviaQuestion {
  id: number;
  question: string;
  options: string[];
  correctAnswer: string;
  category: string;
  clue?: {
    id: number;
    gameId: string;
    value: string;
    text: string;
    answer: string;
    category: {
      id: number;
      title: string;
    };
  };
}

export interface Category {
  id: number;
  title: string;
  triviaCount: number;
}

// Request types
export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  name: string;
  email: string;
  password: string;
}

export interface UpdateUserRequest {
  name?: string;
  email?: string;
  password?: string;
}

export interface CreateApiKeyRequest {
  name: string;
}

export interface UpdateApiKeyRequest {
  name?: string;
  isActive?: boolean;
}

export interface UpdateRateLimitRequest {
  limit: number;
  window: number;
}

export interface SearchParams {
  query: string;
  limit?: number;
  offset?: number;
}

export interface PaginationParams {
  limit?: number;
  offset?: number;
}

// Configuration
export interface ApiConfig {
  baseUrl: string;
  apiKey?: string;
  jwtToken?: string;
}