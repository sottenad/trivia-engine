const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log(`MongoDB Connected: ${conn.connection.host}`);
    
    // Add event listeners for database connection errors
    mongoose.connection.on('error', (err) => {
      console.error('MongoDB connection error:', err);
      // Continue running the app despite DB errors
    });
    
    mongoose.connection.on('disconnected', () => {
      console.log('MongoDB disconnected, attempting to reconnect...');
      // The connection will automatically try to reconnect
    });
    
  } catch (error) {
    console.error('MongoDB connection failed:', error);
    // Don't exit the process, keep the app running even if DB connection fails
    // process.exit(1); // Remove or comment this line if it exists
  }
};

module.exports = connectDB; 