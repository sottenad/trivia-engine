// API Types and Interfaces

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
    question: string;
    answer: string;
    category: {
      id: number;
      title: string;
    };
  };
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    message: string;
    statusCode?: number;
    details?: any;
  };
}

export interface TriviaApiResponse extends ApiResponse<{ trivia: TriviaQuestion }> {}

export interface CategoriesApiResponse extends ApiResponse<{
  count: number;
  categories: Array<{
    id: number;
    title: string;
    triviaCount: number;
  }>;
}> {}

export interface ApiConfig {
  baseUrl: string;
  apiKey?: string;
  headers?: Record<string, string>;
}

export interface PaginationParams {
  limit?: number;
  offset?: number;
}

export interface SearchParams extends PaginationParams {
  query: string;
}