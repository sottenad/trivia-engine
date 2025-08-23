# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a trivia engine project with two main components:
1. **API Backend (`/app`)** - Node.js/Express API for serving trivia questions
2. **Marketing Site (`/marketing`)** - Next.js marketing website

## Common Development Commands

### API Backend (`/app` directory)

```bash
# Install dependencies
npm install

# Run development server (with auto-reload)
npm run dev

# Start production server
npm start

# Run Prisma migrations
npx prisma migrate dev

# Generate Prisma client
npx prisma generate

# Open Prisma Studio (database viewer)
npx prisma studio
```

### Marketing Site (`/marketing` directory)

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Run linting
npm run lint
```

## Architecture Overview

### API Backend Architecture

The API uses a layered architecture:

1. **Entry Point** - `api/index.js` sets up Express server with middleware
2. **Routes** - Defined in `api/routes/` for users, API keys, and trivia
3. **Controllers** - Business logic in `api/controllers/`
4. **Middleware** - Auth, error handling, and rate limiting in `api/middleware/`
5. **Database** - PostgreSQL with Prisma ORM, schema in `prisma/schema.prisma`

Key features:
- JWT authentication for users
- API key authentication for trivia endpoints
- Rate limiting per API key
- Multiple-choice trivia questions generated from Jeopardy clues

### Database Schema

Main models:
- `User` - Application users who can create API keys
- `ApiKey` - Keys for accessing trivia endpoints
- `Category` - Jeopardy categories
- `Clue` - Original Jeopardy clues
- `TriviaQuestion` - Generated multiple-choice questions
- `RateLimit` - Tracks API usage per key

### Batch Processing

The `batch-trivia-processor.js` script generates trivia questions from clues using Ollama AI:
- Processes clues in batches with concurrency control
- Supports resuming from last processed ID
- Generates multiple-choice questions with 3 wrong answers

## Environment Configuration

Create a `.env` file in the `/app` directory:

```env
DATABASE_URL="postgresql://username:password@localhost:5432/dbname"
JWT_SECRET="your-secret-key"
PORT=3003
```

## API Endpoints

Base URL: `http://localhost:3003/api`

Authentication types:
- User endpoints: JWT token in Authorization header
- Trivia endpoints: API key in X-API-Key header

Key endpoints:
- `POST /users` - Register user
- `POST /users/login` - Login and get JWT
- `POST /keys` - Create API key (requires JWT)
- `GET /trivia/random` - Get random trivia question
- `GET /trivia/categories` - List all categories