# J-Archive Clue Extractor

This project extracts Jeopardy! clues from J-Archive and saves them to a PostgreSQL database. It includes tools for extracting individual games or multiple games in sequence.

## Features

- Extracts clues, answers, and categories from J-Archive
- Stores data in a PostgreSQL database using Prisma ORM
- Categories are stored as separate entities with a one-to-many relationship to clues
- Prevents duplicate entries by checking game IDs and question/answer pairs
- Cleans up clue text to remove player names and additional commentary
- Supports batch extraction of multiple games

## Setup

### Prerequisites

- Node.js 14+
- PostgreSQL database
- Docker (optional, for running PostgreSQL in a container)

### Installation

1. Clone this repository
2. Install dependencies
   ```
   npm install
   ```
3. Configure the database connection in `.env`
   ```
   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/jservice?schema=public"
   ```
4. Set up the database schema
   ```
   npx prisma migrate dev --name init
   ```

### Running PostgreSQL in Docker (Optional)

If you don't have PostgreSQL installed locally, you can run it in Docker:

```
docker run --name jservice-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=jservice -p 5432:5432 -d postgres:14
```

## Usage

### Extract a Single Game

To extract clues from a specific game:

```
node extract-game-clues-final.js GAME_ID
```

Replace `GAME_ID` with the desired J-Archive game ID (e.g., `7792`).

### Extract Multiple Games

To extract clues from multiple games in sequence:

1. Edit `extract-multiple-games.js` to include the desired game IDs in the `gameIds` array
2. Run the script:
   ```
   node extract-multiple-games.js
   ```

The script will extract each game with a delay between requests to avoid overloading the J-Archive server.

### Query the Database

To view the extracted data:

```
node query-db.js
```

This script will display statistics about the database, including the number of categories and clues, and sample data.

## Database Schema

The database contains two main tables:

1. **Category**
   - `id` - Primary key
   - `name` - Category name (unique)
   - `createdAt` - Timestamp
   - `updatedAt` - Timestamp
   - Has many `Clue` records

2. **Clue**
   - `id` - Primary key
   - `gameId` - J-Archive game ID
   - `value` - Dollar value (or "FJ" for Final Jeopardy)
   - `question` - The clue text
   - `answer` - The correct response
   - `categoryId` - Foreign key to Category
   - `createdAt` - Timestamp
   - `updatedAt` - Timestamp
   - Belongs to one `Category`

## License

MIT 