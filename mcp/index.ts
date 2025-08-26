#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import axios, { AxiosInstance } from "axios";
import dotenv from "dotenv";
import type {
  ApiResponse,
  TriviaQuestion,
  Category,
  ApiConfig,
  SearchParams,
  PaginationParams
} from "./types.js";

// Load environment variables
dotenv.config();

// Configuration
let config: ApiConfig = {
  baseUrl: process.env.TRIVIA_API_BASE_URL || "http://localhost:3003/api/v1",
  apiKey: process.env.TRIVIA_API_KEY,
  jwtToken: undefined
};

// Create axios instance
let apiClient: AxiosInstance = createApiClient();

function createApiClient(): AxiosInstance {
  const instance = axios.create({
    baseURL: config.baseUrl,
    headers: {
      "Content-Type": "application/json",
      ...(config.apiKey && { "X-API-Key": config.apiKey }),
      ...(config.jwtToken && { "Authorization": `Bearer ${config.jwtToken}` })
    }
  });

  // Add response interceptor for better error handling
  instance.interceptors.response.use(
    response => response,
    error => {
      if (error.response) {
        const errorMessage = error.response.data?.error?.message || 
                           error.response.data?.message || 
                           `API Error: ${error.response.status}`;
        throw new Error(errorMessage);
      }
      throw error;
    }
  );

  return instance;
}

// Create MCP server
const server = new McpServer({
  name: "trivia-engine",
  version: "1.0.0",
  description: "MCP server for Trivia Engine API - access trivia questions, manage users and API keys"
});

// Helper function to format API responses
function formatResponse(data: any): string {
  if (typeof data === 'string') return data;
  return JSON.stringify(data, null, 2);
}

// Helper function to log tool calls
function logToolCall(toolName: string, params?: any, response?: any, error?: any) {
  const timestamp = new Date().toISOString();
  const logEntry: any = {
    timestamp,
    tool: toolName,
  };
  
  // Add parameters if present (redact sensitive data)
  if (params) {
    const safeParams = { ...params };
    if (safeParams.password) safeParams.password = '[REDACTED]';
    if (safeParams.apiKey) safeParams.apiKey = '[REDACTED]';
    if (safeParams.jwtToken) safeParams.jwtToken = '[REDACTED]';
    logEntry.params = safeParams;
  }
  
  // Add response summary if successful
  if (response && !error) {
    if (response.data?.trivia) {
      logEntry.response = `trivia question (id: ${response.data.trivia.id})`;
    } else if (response.data?.categories) {
      logEntry.response = `${response.data.categories.length} categories`;
    } else if (response.data?.triviaList) {
      logEntry.response = `${response.data.triviaList.length} trivia questions`;
    } else if (response.success !== undefined) {
      logEntry.response = response.success ? 'success' : 'failed';
    } else {
      logEntry.response = 'completed';
    }
  }
  
  // Add error if present
  if (error) {
    logEntry.error = error.message || 'Unknown error';
  }
  
  // Log with appropriate emoji
  const emoji = error ? '✗' : '✓';
  console.error(`${emoji} MCP Tool: ${toolName}`, JSON.stringify(logEntry));
}

// Configuration Tools
server.tool(
  "set_api_config",
  "Configure the API connection settings (base URL, API key, JWT token)",
  {
    baseUrl: z.string().url().optional().describe("API base URL (e.g., http://localhost:3003/api/v1)"),
    apiKey: z.string().optional().describe("API key for trivia endpoints"),
    jwtToken: z.string().optional().describe("JWT token for user/admin endpoints")
  },
  async ({ baseUrl, apiKey, jwtToken }) => {
    const params = { baseUrl, apiKey, jwtToken };
    try {
      if (baseUrl) config.baseUrl = baseUrl;
      if (apiKey !== undefined) config.apiKey = apiKey;
      if (jwtToken !== undefined) config.jwtToken = jwtToken;
      
      // Recreate axios instance with new config
      apiClient = createApiClient();
      
      const response = {
        success: true,
        config: {
          baseUrl: config.baseUrl,
          hasApiKey: !!config.apiKey,
          hasJwtToken: !!config.jwtToken
        }
      };
      
      logToolCall("set_api_config", params, response);
      
      return {
        content: [{
          type: "text",
          text: `API configuration updated:\n- Base URL: ${config.baseUrl}\n- API Key: ${config.apiKey ? 'Set' : 'Not set'}\n- JWT Token: ${config.jwtToken ? 'Set' : 'Not set'}`
        }]
      };
    } catch (error) {
      logToolCall("set_api_config", params, null, error);
      throw error;
    }
  });

server.tool(
  "check_health",
  "Check if the Trivia Engine API is healthy and accessible",
  async () => {
    try {
      const response = await apiClient.get("/health");
      logToolCall("check_health", undefined, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("check_health", undefined, null, error);
      return {
        content: [{
          type: "text",
          text: `Health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });


// Trivia Tools
server.tool(
  "get_random_trivia",
  "Get a random trivia question (requires API key)",
  {
    category: z.string().optional().describe("Filter by category name")
  },
  async ({ category }) => {
    const toolParams = { category };
    try {
      const params = category ? { category } : undefined;
      const response = await apiClient.get<ApiResponse<{ trivia: TriviaQuestion }>>("/trivia/random", { params });
      logToolCall("get_random_trivia", toolParams, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("get_random_trivia", toolParams, null, error);
      return {
        content: [{
          type: "text",
          text: `Failed to get trivia: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });

server.tool(
  "get_trivia_by_id",
  "Get a specific trivia question by ID (requires API key)",
  {
    id: z.number().describe("Trivia question ID")
  },
  async ({ id }) => {
    const params = { id };
    try {
      const response = await apiClient.get<ApiResponse<{ trivia: TriviaQuestion }>>(`/trivia/${id}`);
      logToolCall("get_trivia_by_id", params, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("get_trivia_by_id", params, null, error);
      return {
        content: [{
          type: "text",
          text: `Failed to get trivia: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });

server.tool(
  "get_trivia_by_category",
  "Get trivia questions from a specific category (requires API key)",
  {
    categoryTitle: z.string().describe("Category name"),
    limit: z.number().min(1).max(100).optional().describe("Number of questions (default 10)"),
    offset: z.number().min(0).optional().describe("Starting position (default 0)")
  },
  async ({ categoryTitle, limit, offset }) => {
    const toolParams = { categoryTitle, limit, offset };
    try {
      const params: PaginationParams = {};
      if (limit !== undefined) params.limit = limit;
      if (offset !== undefined) params.offset = offset;
      
      const response = await apiClient.get<ApiResponse>(`/trivia/category/${encodeURIComponent(categoryTitle)}`, { params });
      logToolCall("get_trivia_by_category", toolParams, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("get_trivia_by_category", toolParams, null, error);
      return {
        content: [{
          type: "text",
          text: `Failed to get category trivia: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });

server.tool(
  "list_categories",
  "List all available trivia categories (requires API key)",
  async () => {
    try {
      const response = await apiClient.get<ApiResponse<{ categories: Category[] }>>("/trivia/categories");
      logToolCall("list_categories", undefined, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("list_categories", undefined, null, error);
      return {
        content: [{
          type: "text",
          text: `Failed to list categories: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });

server.tool(
  "search_trivia",
  "Search for trivia questions containing specific terms (requires API key)",
  {
    query: z.string().describe("Search term"),
    limit: z.number().min(1).max(100).optional().describe("Number of results (default 10)"),
    offset: z.number().min(0).optional().describe("Starting position (default 0)")
  },
  async ({ query, limit, offset }) => {
    const toolParams = { query, limit, offset };
    try {
      const params: SearchParams = { query };
      if (limit !== undefined) params.limit = limit;
      if (offset !== undefined) params.offset = offset;
      
      const response = await apiClient.get<ApiResponse>("/trivia/search", { params });
      logToolCall("search_trivia", toolParams, response.data);
      return {
        content: [{
          type: "text",
          text: formatResponse(response.data)
        }]
      };
    } catch (error) {
      logToolCall("search_trivia", toolParams, null, error);
      return {
        content: [{
          type: "text",
          text: `Search failed: ${error instanceof Error ? error.message : 'Unknown error'}`
        }]
      };
    }
  });

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  
  console.error("Trivia Engine MCP Server running");
  console.error(`Connected to: ${config.baseUrl}`);
  console.error(`API Key: ${config.apiKey ? 'Set' : 'Not set'}`);
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});