# Trivia Engine MCP Server - Technical Architecture

## Overview

This MCP server provides a bridge between Claude Desktop and the Trivia Engine REST API, implementing the Model Context Protocol (MCP) specification with stdio transport. The server exposes trivia operations, user management, and API key administration through a tool-based interface.

## Architecture Decisions & Rationale

### 1. Transport Layer: stdio over HTTP/WebSocket

**Decision**: Use `StdioServerTransport` for client-server communication.

**Rationale**:
- **Process isolation**: Claude Desktop spawns the MCP server as a child process, providing natural sandboxing
- **No network overhead**: Direct IPC via stdin/stdout eliminates network latency and configuration
- **Platform compatibility**: stdio works identically across Windows, macOS, and Linux
- **Security**: No exposed ports, no TLS/auth configuration needed at transport layer
- **Simplicity**: No connection management, reconnection logic, or network error handling required

The stdio transport aligns with MCP's philosophy of simplicity while maintaining security through process boundaries.

### 2. TypeScript with Strict Configuration

**Decision**: TypeScript with strict mode, ESM modules, and comprehensive type checking.

**Rationale**:
- **Type safety**: Prevents runtime errors in tool parameter handling
- **ESM modules**: Future-proof module system, required by MCP SDK
- **Source maps**: Enhanced debugging experience in production
- **Declaration files**: Enable type checking for consumers if needed
- **Strict null checks**: Critical for handling optional API responses

### 3. Zod for Runtime Validation

**Decision**: Use Zod schemas for tool parameter validation instead of relying solely on TypeScript.

**Rationale**:
- **Runtime safety**: MCP protocol sends JSON, requiring runtime validation
- **Schema inference**: Zod provides TypeScript types from schemas
- **Error messages**: Better validation errors for Claude's tool invocation
- **MCP SDK integration**: Native support in `@modelcontextprotocol/sdk`

### 4. Axios with Interceptors for API Client

**Decision**: Axios instance with response interceptors for error normalization.

**Rationale**:
- **Error standardization**: Interceptor extracts error messages from various API response formats
- **Header management**: Centralized auth header injection (API key vs JWT)
- **Request/response transformation**: Clean separation of protocol concerns
- **Retry capability**: Easy to add retry logic for transient failures

### 5. Dual Authentication Strategy

**Decision**: Support both JWT (for user operations) and API keys (for trivia access).

**Rationale**:
- **Separation of concerns**: User management requires session-based auth, trivia access needs long-lived keys
- **Rate limiting**: API keys enable per-key rate limiting at the API layer
- **Security**: JWTs expire, reducing risk for admin operations
- **Flexibility**: Users can create multiple API keys with different permissions

### 6. Stateful Configuration Management

**Decision**: Maintain mutable configuration state (`config` object) within the server process.

**Rationale**:
- **Tool workflow**: `set_api_config` tool allows runtime configuration changes
- **Developer experience**: No need to restart MCP server to change API endpoints
- **Testing**: Easy to switch between environments during development
- **Trade-off**: Accepts statefulness for improved UX, mitigated by process isolation

### 7. Stderr Logging with Structured Output

**Decision**: Log all tool invocations to stderr with JSON structure and emoji indicators.

**Rationale**:
- **Separation from protocol**: stderr doesn't interfere with stdio JSON-RPC communication
- **Debugging**: Claude Desktop captures stderr for developer console
- **Structured logs**: JSON format enables log parsing and analysis
- **Visual feedback**: Emoji indicators (✓/✗) provide quick success/failure recognition
- **Security**: Automatic redaction of sensitive parameters (passwords, tokens)

## System Topology

```
┌─────────────────┐
│ Claude Desktop  │
│   (Electron)    │
└────────┬────────┘
         │ stdio (JSON-RPC 2.0)
         │ Process spawn
┌────────▼────────┐
│   MCP Server    │
│  (Node.js/TS)   │
│                 │
│ Tools:          │
│ - set_api_config│
│ - get_trivia    │
│ - user_mgmt     │
└────────┬────────┘
         │ HTTPS
         │ REST API
┌────────▼────────┐
│  Trivia API     │
│ (Express/Node)  │
│                 │
│ Middleware:     │
│ - JWT Auth      │
│ - API Key Auth  │
│ - Rate Limiting │
└────────┬────────┘
         │ SQL (Prisma)
┌────────▼────────┐
│   PostgreSQL    │
│                 │
│ Tables:         │
│ - Users         │
│ - ApiKeys       │
│ - TriviaQuestions│
│ - Categories    │
└─────────────────┘
```

### Communication Flow

1. **Tool Invocation**: Claude Desktop sends JSON-RPC request via stdin
2. **Parameter Validation**: Zod validates against tool schema
3. **API Request**: Axios client makes HTTP request with appropriate auth
4. **Response Transform**: Format API response for MCP protocol
5. **Result Return**: JSON-RPC response sent via stdout

### Security Boundaries

1. **Process Boundary**: MCP server runs as separate process with limited permissions
2. **Authentication Boundary**: Dual auth strategy based on operation type
3. **Network Boundary**: HTTPS for API communication
4. **Data Boundary**: Automatic redaction of sensitive data in logs

## Implementation Patterns

### Tool Registration Pattern

```typescript
server.tool(
  "tool_name",           // Unique identifier
  "Description",         // Human-readable description
  zodSchema,            // Parameter validation schema
  async (params) => {   // Handler function
    // 1. Log invocation
    // 2. Make API request
    // 3. Handle errors
    // 4. Format response
    // 5. Return MCP content
  }
);
```

This pattern ensures consistency across all tool implementations.

### Error Handling Strategy

Three-layer error handling:

1. **API Layer**: Axios interceptor normalizes API errors
2. **Tool Layer**: Try-catch wraps each tool handler
3. **Log Layer**: All errors logged with context

This provides graceful degradation and debugging information.

### Response Formatting

All responses follow MCP content structure:
```typescript
{
  content: [{
    type: "text",
    text: string  // JSON stringified for complex objects
  }]
}
```

JSON stringification with 2-space indentation ensures readable output in Claude Desktop.

## Design Trade-offs

### 1. Client-side HTTP vs Server-side Proxy

**Chose**: Client-side HTTP (MCP server makes direct API calls)

**Alternative**: API server could expose MCP protocol directly

**Trade-offs**:
- ✅ Separation of concerns - API remains protocol-agnostic
- ✅ Flexibility - Easy to add caching, transformation
- ❌ Additional moving part - MCP server must be maintained
- ❌ Double serialization - JSON → HTTP → JSON

### 2. Tool Granularity

**Chose**: One tool per API endpoint (e.g., `get_random_trivia`, `get_trivia_by_category`)

**Alternative**: Fewer tools with more parameters (e.g., `get_trivia` with `mode` parameter)

**Trade-offs**:
- ✅ Clarity - Each tool has single purpose
- ✅ Discovery - Claude can better understand available operations
- ❌ Tool proliferation - More tools to maintain
- ❌ Potential duplication - Similar code across tools

### 3. Stateful vs Stateless Configuration

**Chose**: Stateful configuration with `set_api_config` tool

**Alternative**: Pass config with each request or use environment variables only

**Trade-offs**:
- ✅ Developer experience - No restart required for config changes
- ✅ Testing flexibility - Easy to switch environments
- ❌ State management - Must handle config updates correctly
- ❌ Potential inconsistency - Config could drift from environment

### 4. Error Response Format

**Chose**: Return errors as successful MCP responses with error text

**Alternative**: Use MCP error responses

**Trade-offs**:
- ✅ User visibility - Errors shown in Claude's interface
- ✅ Graceful handling - Doesn't break tool invocation flow
- ❌ Semantic correctness - Success with error message is contradictory
- ❌ Error handling - Harder for automated error detection

## Performance Considerations

1. **Axios Instance Reuse**: Single axios instance avoids connection overhead
2. **No Connection Pooling**: Each request creates new HTTPS connection (acceptable for interactive use)
3. **Synchronous Tool Execution**: Tools execute sequentially (MCP protocol limitation)
4. **Memory Footprint**: Minimal - only active config and axios instance retained

## Future Considerations

1. **Streaming Responses**: For large result sets (not currently implemented)
2. **Caching Layer**: Could cache category lists and static data
3. **Retry Logic**: Axios retry adapter for transient failures
4. **WebSocket Transport**: If MCP adds support, could reduce stdio overhead
5. **Resource Management**: Tool for checking rate limit status

## Conclusion

This MCP server implementation prioritizes developer experience and security while maintaining simplicity. The architecture decisions align with MCP's design principles while providing a robust bridge to the Trivia Engine API. The stateful configuration and comprehensive logging make it suitable for both development and production use within Claude Desktop's process-isolated environment.