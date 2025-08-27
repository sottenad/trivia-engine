# Trivia Engine MCP Server

A Model Context Protocol (MCP) server that provides comprehensive access to the Trivia Engine API, enabling AI assistants to interact with trivia questions, manage users, and handle API keys.

## Installation

```bash
cd mcp
npm install
npm run build
```

## Configuration

The MCP server can be configured through environment variables:

```bash
# Create a .env file
TRIVIA_API_BASE_URL=http://localhost:3003/api/v1
TRIVIA_API_KEY=your-api-key-here
```

## Available Tools

### Configuration Tools

- **set_api_config** - Configure API connection settings (base URL, API key, JWT token)
- **check_health** - Check if the Trivia Engine API is healthy and accessible

### User Management Tools

- **register_user** - Register a new user account
- **login_user** - Login with email and password to get JWT token
- **get_user_profile** - Get the current user's profile (requires JWT)
- **update_user_profile** - Update the current user's profile (requires JWT)

### API Key Management Tools

- **create_api_key** - Create a new API key (requires JWT)
- **list_api_keys** - List all API keys for the current user (requires JWT)
- **get_api_key** - Get details of a specific API key (requires JWT)
- **update_api_key** - Update an API key's name or active status (requires JWT)
- **delete_api_key** - Delete an API key (requires JWT)
- **update_rate_limit** - Update rate limits for an API key (requires JWT)

### Trivia Tools

- **get_random_trivia** - Get a random trivia question (requires API key)
- **get_trivia_by_id** - Get a specific trivia question by ID (requires API key)
- **get_trivia_by_category** - Get trivia questions from a specific category (requires API key)
- **list_categories** - List all available trivia categories (requires API key)
- **search_trivia** - Search for trivia questions containing specific terms (requires API key)

## Usage with Claude Desktop

Add the following to your Claude Desktop configuration file:

### Windows
Edit `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "trivia-engine": {
      "command": "node",
      "args": ["C:\\projects\\trivia-engine\\mcp\\build\\index.js"],
      "env": {
        "TRIVIA_API_BASE_URL": "http://localhost:3003/api/v1",
        "TRIVIA_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

### macOS
Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "trivia-engine": {
      "command": "node",
      "args": ["/path/to/trivia-engine/mcp/build/index.js"],
      "env": {
        "TRIVIA_API_BASE_URL": "http://localhost:3003/api/v1",
        "TRIVIA_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

### Linux
Edit `~/.config/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "trivia-engine": {
      "command": "node",
      "args": ["/path/to/trivia-engine/mcp/build/index.js"],
      "env": {
        "TRIVIA_API_BASE_URL": "http://localhost:3003/api/v1",
        "TRIVIA_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

## Example Usage

Once configured and Claude Desktop is restarted, you can use the tools like this:

```
// First, configure the API connection
set_api_config baseUrl="http://localhost:3003/api/v1" apiKey="your-api-key"

// Check if the API is healthy
check_health

// Get a random trivia question
get_random_trivia

// Search for trivia about space
search_trivia query="space" limit=5

// List all categories
list_categories

// Get trivia from a specific category
get_trivia_by_category categoryTitle="Science" limit=10
```

## Authentication Flow

1. For user-specific operations (creating API keys, managing profile):
   ```
   // Register a new user
   register_user name="John Doe" email="john@example.com" password="securePassword123"
   
   // Or login with existing account
   login_user email="john@example.com" password="securePassword123"
   
   // Now you can create API keys
   create_api_key name="My App"
   ```

2. For trivia operations, you need an API key:
   ```
   // Set your API key
   set_api_config apiKey="sk_your_api_key_here"
   
   // Now you can access trivia
   get_random_trivia
   ```

## Development

```bash
# Build the TypeScript code
npm run build

# Watch for changes during development
npm run dev

# Run the server directly
npm start
```

## Docker Support

The MCP server can be run in Docker for better isolation and deployment.

### Quick Start with Docker

```bash
# Build the Docker image
npm run docker:build

# Run with Docker (reads .env file)
npm run docker:run

# Or use docker-compose
npm run docker:compose:up
```

### Docker Configuration

#### Using Docker with Claude Desktop

Update your Claude Desktop configuration to use Docker:

```json
{
  "mcpServers": {
    "trivia-engine": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--env", "TRIVIA_API_BASE_URL=http://host.docker.internal:3003/api/v1",
        "--env", "TRIVIA_API_KEY=your-api-key-here",
        "trivia-engine-mcp:latest"
      ]
    }
  }
}
```

#### Development with Docker

For development with hot reload:

```bash
# Build development image
npm run docker:build:dev

# Run with docker-compose (includes volume mounts)
npm run docker:run:dev
```

#### Environment Variables

Create a `.env` file for Docker:

```env
TRIVIA_API_BASE_URL=http://host.docker.internal:3003/api/v1
TRIVIA_API_KEY=your-api-key-here
```

Note: `host.docker.internal` allows the container to access services on your host machine.

#### Using with Toolhive

If using Stacklok Toolhive, you can deploy the Docker image:

```bash
# Run with Toolhive
thv run trivia-engine-mcp --image trivia-engine-mcp:latest \
  --env TRIVIA_API_BASE_URL=http://host.docker.internal:3003/api/v1 \
  --env TRIVIA_API_KEY=your-api-key-here
```

Then configure Claude Desktop to use Toolhive's proxy:

```json
{
  "mcpServers": {
    "trivia-engine": {
      "command": "thv",
      "args": ["proxy", "trivia-engine-mcp"]
    }
  }
}
```

## Error Handling

The MCP server includes comprehensive error handling:
- API connection errors are caught and returned with helpful messages
- Authentication errors provide clear feedback about missing tokens or invalid credentials
- Rate limit errors include information about when to retry

## Security Notes

- Never commit your `.env` file with real API keys
- JWT tokens are automatically managed after login/register
- API keys should be kept secure and rotated regularly
- The server validates all inputs using Zod schemas

## Logging

The MCP server logs all tool calls to stderr (which appears in Claude Desktop's logs). Each log entry includes:
- Timestamp
- Tool name
- Parameters (with sensitive data redacted)
- Response summary (e.g., "trivia question (id: 123)", "5 categories")
- Error messages if the call failed

Example log output:
```
✓ MCP Tool: set_api_config {"timestamp":"2024-01-10T12:00:00.000Z","tool":"set_api_config","params":{"apiKey":"[REDACTED]"},"response":"success"}
✓ MCP Tool: get_random_trivia {"timestamp":"2024-01-10T12:00:01.000Z","tool":"get_random_trivia","params":{"category":"Science"},"response":"trivia question (id: 42)"}
✗ MCP Tool: search_trivia {"timestamp":"2024-01-10T12:00:02.000Z","tool":"search_trivia","params":{"query":"astronomy"},"error":"API key invalid"}
```