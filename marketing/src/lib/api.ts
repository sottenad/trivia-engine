// API Client Library

import { 
  ApiConfig, 
  TriviaApiResponse, 
  CategoriesApiResponse,
  SearchParams 
} from '@/types/api';

class ApiClient {
  private config: ApiConfig;

  constructor(config?: Partial<ApiConfig>) {
    this.config = {
      baseUrl: process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3003/api/v1',
      apiKey: process.env.NEXT_PUBLIC_API_KEY,
      ...config,
    };
  }

  private async request<T>(endpoint: string, options?: RequestInit): Promise<T> {
    const url = `${this.config.baseUrl}${endpoint}`;
    
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...this.config.headers,
      ...options?.headers,
    };

    // Only add API key if it exists and is not a placeholder
    if (this.config.apiKey && this.config.apiKey !== 'your-api-key-here') {
      headers['X-API-Key'] = this.config.apiKey;
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error?.message || `API Error: ${response.status}`);
      }

      return data;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('Network error occurred');
    }
  }

  async getRandomTrivia(category?: string): Promise<TriviaApiResponse> {
    const params = new URLSearchParams();
    if (category) params.append('category', category);
    
    const endpoint = params.toString() 
      ? `/trivia/random?${params.toString()}`
      : '/trivia/random';
      
    return this.request<TriviaApiResponse>(endpoint);
  }

  async getTriviaById(id: number): Promise<TriviaApiResponse> {
    return this.request<TriviaApiResponse>(`/trivia/${id}`);
  }

  async getCategories(): Promise<CategoriesApiResponse> {
    return this.request<CategoriesApiResponse>('/trivia/categories');
  }

  async getTriviaByCategory(
    categoryTitle: string, 
    limit?: number, 
    offset?: number
  ): Promise<TriviaApiResponse> {
    const params = new URLSearchParams();
    if (limit) params.append('limit', limit.toString());
    if (offset) params.append('offset', offset.toString());
    
    const endpoint = params.toString()
      ? `/trivia/category/${encodeURIComponent(categoryTitle)}?${params.toString()}`
      : `/trivia/category/${encodeURIComponent(categoryTitle)}`;
      
    return this.request<TriviaApiResponse>(endpoint);
  }

  async searchTrivia(searchParams: SearchParams): Promise<TriviaApiResponse> {
    const params = new URLSearchParams();
    params.append('query', searchParams.query);
    if (searchParams.limit) params.append('limit', searchParams.limit.toString());
    if (searchParams.offset) params.append('offset', searchParams.offset.toString());
    
    return this.request<TriviaApiResponse>(`/trivia/search?${params.toString()}`);
  }
}

// Export a singleton instance
export const apiClient = new ApiClient();

// Export the class for custom instances
export default ApiClient;