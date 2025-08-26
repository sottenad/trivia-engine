const { PrismaClient } = require('@prisma/client');
const config = require('./index');

// Create a singleton instance of Prisma Client
class Database {
  constructor() {
    if (!Database.instance) {
      this.client = new PrismaClient({
        log: ['error', 'warn'], // Only show errors and warnings, no queries
        datasources: {
          db: {
            url: config.database.url,
          },
        },
      });
      
      // Handle connection events
      this.client.$connect()
        .then(() => {
          console.log('Database connected successfully');
        })
        .catch((error) => {
          console.error('Failed to connect to database:', error);
          process.exit(1);
        });
      
      Database.instance = this;
    }
    
    return Database.instance;
  }
  
  getClient() {
    return this.client;
  }
  
  async disconnect() {
    await this.client.$disconnect();
    console.log('Database disconnected');
  }
}

// Create and export singleton instance
const database = new Database();
const prisma = database.getClient();

// Handle process termination
process.on('beforeExit', async () => {
  await database.disconnect();
});

module.exports = { prisma, database };