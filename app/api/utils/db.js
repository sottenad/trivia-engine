const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log(`MongoDB Connected: ${conn.connection.host}`);
    
    // Handle DB connection errors after initial connection
    mongoose.connection.on('error', (err) => {
      console.error(`MongoDB connection error: ${err}`);
      // Log error but don't crash the app
    });
    
  } catch (error) {
    console.error(`Error connecting to MongoDB: ${error.message}`);
    // Don't crash the app - instead return the error to be handled
    return error;
  }
};

module.exports = connectDB; 