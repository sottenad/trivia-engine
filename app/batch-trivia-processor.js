const { PrismaClient } = require('@prisma/client');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const prisma = new PrismaClient();

// Configuration
const MODEL_NAME = 'qwq:32b';
const BATCH_SIZE = 1000;  // Number of clues to process in one batch
const CONCURRENCY = 5;   // Number of simultaneous API calls
const DELAY_BETWEEN_REQUESTS = 10; // 1 second between API calls
const DELAY_BETWEEN_BATCHES = 10;  // 1 minute between batches
const LOG_FILE = './trivia_generation_log.txt';
const ERROR_FILE = './trivia_generation_errors.txt';
const RESUME_FILE = './trivia_generation_progress.json';

// Get command line arguments
const startIdArg = process.argv[2] ? parseInt(process.argv[2]) : null;
const endIdArg = process.argv[3] ? parseInt(process.argv[3]) : null;
const shouldResume = process.argv.includes('--resume');
const skipExisting = !process.argv.includes('--force');

// Logging functions
function logMessage(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}`;
  console.log(logMessage);
  fs.appendFileSync(LOG_FILE, logMessage + '\n');
}

function logError(message, error) {
  const timestamp = new Date().toISOString();
  const errorMessage = `[${timestamp}] ERROR: ${message}\n${error?.stack || error}\n`;
  console.error(errorMessage);
  fs.appendFileSync(ERROR_FILE, errorMessage + '\n');
}

// Save progress to allow resuming
function saveProgress(lastId, processed, errors) {
  const progressData = {
    lastProcessedId: lastId,
    processedCount: processed,
    errorCount: errors,
    lastUpdated: new Date().toISOString()
  };
  fs.writeFileSync(RESUME_FILE, JSON.stringify(progressData, null, 2));
}

// Function to generate a trivia question using Ollama API
async function generateTriviaQuestion(clue) {
  try {
    const prompt = `
You are generating a multiple-choice trivia question based on a Jeopardy! clue.

Original Category: ${clue.category.name}
Original Clue: ${clue.question}
Correct Answer: ${clue.answer}

Please rephrase this into a clear, engaging multiple-choice trivia question. 

Create a set of 3 plausible wrong answers that:
- Are related to the category
- Different from each other
- In a similar format/style as the correct answer
- Are somewhat plausible but clearly incorrect to someone who knows the subject

The wrong answers should be at a medium difficulty level - not too obvious, but not extremely tricky.

Return as JSON.
`;

    // Define the schema for structured output with only medium difficulty
    const outputSchema = {
      type: "object",
      properties: {
        question: {
          type: "string",
          description: "The rephrased trivia question"
        },
        correctAnswer: {
          type: "string",
          description: "The correct answer to the question"
        },
        wrongAnswers: {
          type: "array",
          items: {
            type: "string"
          },
          description: "Three plausible but incorrect answers",
          minItems: 3,
          maxItems: 3
        }
      },
      required: ["question", "correctAnswer", "wrongAnswers"]
    };
    
    const response = await axios.post('http://127.0.0.1:11434/api/generate', {
      model: MODEL_NAME,
      prompt: prompt,
      format: outputSchema,
      stream: false
    });
    
    // With structured outputs, the response should already be in the correct format
    const result = response.data.response;
    
    try {
      // Parse the response if it's a string, otherwise use as is
      const parsedResult = typeof result === 'string' ? JSON.parse(result) : result;
      
      // Ensure we have exactly 3 wrong answers
      if (parsedResult.wrongAnswers && parsedResult.wrongAnswers.length > 3) {
        parsedResult.wrongAnswers = parsedResult.wrongAnswers.slice(0, 3);
      }
      
      return parsedResult;
    } catch (error) {
      logError(`Error parsing structured output for clue ${clue.id}`, error);
      logError(`Raw response for clue ${clue.id}:`, result);
      
      // Create fallback data
      return {
        question: `In the category "${clue.category.name}": ${clue.question}`,
        correctAnswer: clue.answer,
        wrongAnswers: [
          "Wrong option 1",
          "Wrong option 2", 
          "Wrong option 3"
        ]
      };
    }
  } catch (error) {
    logError(`Error calling Ollama API for clue ${clue.id}:`, error);
    
    // More detailed error information
    if (error.code === 'ECONNREFUSED') {
      logError('Connection refused. Make sure Ollama is running on port 11434', error);
    } else if (error.response) {
      logError(`Response status for clue ${clue.id}: ${error.response.status}`, error);
      logError(`Response data for clue ${clue.id}:`, error.response.data);
    } else if (error.request) {
      logError('No response received', error);
    }
    
    throw error;
  }
}

// Function to save trivia question to the database
async function saveTriviaQuestion(clue, triviaData) {
  try {
    // Ensure we have all the required data
    if (!triviaData.question || !triviaData.wrongAnswers) {
      throw new Error('Missing required data for saving trivia question');
    }
    
    // Make sure wrong answers array has at least 3 items
    const wrongAnswers = [...(triviaData.wrongAnswers || [])];
    while (wrongAnswers.length < 3) {
      wrongAnswers.push(`Filler answer ${wrongAnswers.length + 1}`);
    }
    
    // Create the trivia question in the database
    const newTriviaQuestion = await prisma.triviaQuestion.create({
      data: {
        clueId: clue.id,
        rephrased: triviaData.question,
        correctAnswer: triviaData.correctAnswer,
        wrongAnswer1: wrongAnswers[0],
        wrongAnswer2: wrongAnswers[1],
        wrongAnswer3: wrongAnswers[2],
        model: MODEL_NAME
      }
    });
    
    return newTriviaQuestion;
  } catch (error) {
    logError(`Error saving trivia question for clue ${clue.id} to database:`, error);
    throw error;
  }
}

// Function to process a single clue with retry logic
async function processClue(clue, retryCount = 3) {
  try {
    // Check if we already have a trivia question for this clue
    if (skipExisting) {
      const existingTrivia = await prisma.triviaQuestion.findFirst({
        where: { clueId: clue.id }
      });
      
      if (existingTrivia) {
        logMessage(`Skipping clue ID ${clue.id} - already has trivia question`);
        return { success: true, skipped: true, clueId: clue.id };
      }
    }
    
    // Generate trivia question
    const triviaData = await generateTriviaQuestion(clue);
    
    // Save to database
    await saveTriviaQuestion(clue, triviaData);
    
    logMessage(`Successfully processed clue ID ${clue.id}`);
    return { success: true, clueId: clue.id };
  } catch (error) {
    if (retryCount > 0) {
      logMessage(`Retrying clue ID ${clue.id}, ${retryCount} attempts remaining`);
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds before retry
      return processClue(clue, retryCount - 1);
    } else {
      logError(`Failed to process clue ID ${clue.id} after multiple attempts`, error);
      return { success: false, clueId: clue.id, error: error.message };
    }
  }
}

// Function to process a batch of clues with concurrency control
async function processBatch(clues) {
  const results = [];
  const queue = [...clues];
  const inProgress = new Set();
  
  while (queue.length > 0 || inProgress.size > 0) {
    // Fill up to concurrency limit
    while (queue.length > 0 && inProgress.size < CONCURRENCY) {
      const clue = queue.shift();
      
      // Process clue and add to results when done
      inProgress.add(clue.id);
      processClue(clue)
        .then(result => {
          results.push(result);
          inProgress.delete(clue.id);
        })
        .catch(error => {
          logError(`Unexpected error processing clue ${clue.id}:`, error);
          results.push({ success: false, clueId: clue.id, error: error.message });
          inProgress.delete(clue.id);
        });
      
      // Add delay between starting requests
      await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_REQUESTS));
    }
    
    // Wait a bit for processing to continue
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  return results;
}

// Main function to process all clues in batches
async function processAllClues() {
  try {
    // Initialize progress tracking
    let processedCount = 0;
    let errorCount = 0;
    let lastProcessedId = 0;
    
    // Create log files if they don't exist
    if (!fs.existsSync(path.dirname(LOG_FILE)) && path.dirname(LOG_FILE) !== '.') {
      fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
    }
    if (!fs.existsSync(path.dirname(ERROR_FILE)) && path.dirname(ERROR_FILE) !== '.') {
      fs.mkdirSync(path.dirname(ERROR_FILE), { recursive: true });
    }
    
    // If resuming, load progress data
    if (shouldResume && fs.existsSync(RESUME_FILE)) {
      const progressData = JSON.parse(fs.readFileSync(RESUME_FILE, 'utf8'));
      lastProcessedId = progressData.lastProcessedId || 0;
      processedCount = progressData.processedCount || 0;
      errorCount = progressData.errorCount || 0;
      
      logMessage(`Resuming from clue ID ${lastProcessedId}, already processed ${processedCount} clues`);
    } else {
      // Start fresh log files
      fs.writeFileSync(LOG_FILE, `Starting new batch processing at ${new Date().toISOString()}\n`);
      fs.writeFileSync(ERROR_FILE, `Error log for batch processing starting at ${new Date().toISOString()}\n`);
    }

    // Get total number of clues to process
    const whereClause = {};
    if (startIdArg !== null) {
      whereClause.id = { gte: startIdArg };
    }
    if (endIdArg !== null) {
      whereClause.id = { ...(whereClause.id || {}), lte: endIdArg };
    }
    if (lastProcessedId > 0) {
      whereClause.id = { ...(whereClause.id || {}), gt: lastProcessedId };
    }
    
    const totalClues = await prisma.clue.count({ where: whereClause });
    logMessage(`Starting batch processing for ${totalClues} clues`);
    
    // Process clues in batches
    let batchNum = 1;
    let cursor = lastProcessedId;
    let hasMore = true;
    
    while (hasMore) {
      // Get next batch of clues
      logMessage(`Processing batch ${batchNum} (clues > ID ${cursor})`);
      
      const clues = await prisma.clue.findMany({
        where: {
          id: { gt: cursor },
          ...(endIdArg ? { id: { lte: endIdArg } } : {}),
          ...(startIdArg && cursor === lastProcessedId ? { id: { gte: startIdArg } } : {})
        },
        include: { category: true },
        orderBy: { id: 'asc' },
        take: BATCH_SIZE
      });
      
      if (clues.length === 0) {
        logMessage('No more clues to process');
        hasMore = false;
        break;
      }
      
      logMessage(`Found ${clues.length} clues in batch ${batchNum}`);
      
      // Process this batch
      const batchResults = await processBatch(clues);
      
      // Update progress
      const batchSuccesses = batchResults.filter(r => r.success).length;
      const batchErrors = batchResults.filter(r => !r.success).length;
      const batchSkipped = batchResults.filter(r => r.success && r.skipped).length;
      
      processedCount += batchSuccesses;
      errorCount += batchErrors;
      
      // Update cursor to last processed ID
      const lastClue = clues[clues.length - 1];
      cursor = lastClue.id;
      lastProcessedId = cursor;
      
      // Save progress
      saveProgress(lastProcessedId, processedCount, errorCount);
      
      logMessage(`Batch ${batchNum} completed: ${batchSuccesses} successful (${batchSkipped} skipped), ${batchErrors} failed`);
      logMessage(`Progress: ${processedCount}/${totalClues} clues processed (${errorCount} errors)`);
      
      // Wait between batches if there are more to process
      if (clues.length === BATCH_SIZE) {
        logMessage(`Waiting ${DELAY_BETWEEN_BATCHES/1000} seconds before next batch...`);
        await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_BATCHES));
      } else {
        hasMore = false;
      }
      
      batchNum++;
    }
    
    logMessage(`Batch processing complete. Processed ${processedCount} clues with ${errorCount} errors.`);
  } catch (error) {
    logError('Fatal error in batch processing:', error);
  } finally {
    await prisma.$disconnect();
  }
}

// Display usage information
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
Usage: 
  node batch-trivia-processor.js [startId] [endId] [options]

Arguments:
  startId    - Optional. The starting clue ID (inclusive)
  endId      - Optional. The ending clue ID (inclusive)

Options:
  --resume   - Resume from last processed clue ID
  --force    - Process all clues, even if they already have trivia questions
  --help, -h - Display this help message

Examples:
  node batch-trivia-processor.js                    # Process all clues
  node batch-trivia-processor.js 1000 2000          # Process clues from ID 1000 to 2000
  node batch-trivia-processor.js --resume           # Resume from last processed ID
  node batch-trivia-processor.js 1000 --force       # Process all clues from ID 1000, even existing ones
  `);
  process.exit(0);
}

// Start processing
processAllClues(); 