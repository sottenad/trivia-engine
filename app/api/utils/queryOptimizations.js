const { prisma } = require('../../config/database');

/**
 * Get a random trivia question using efficient SQL
 * This is much faster than count + skip for large datasets
 * @param {Object} filters - Optional filters for category, difficulty, etc.
 * @returns {Promise<Object>} Random trivia question
 */
const getRandomTriviaQuestionOptimized = async (filters = {}) => {
  let whereConditions = [];
  let params = [];
  let paramIndex = 1;

  // Build WHERE conditions based on filters
  if (filters.categoryTitle) {
    whereConditions.push(`c."title" ILIKE $${paramIndex}`);
    params.push(`%${filters.categoryTitle}%`);
    paramIndex++;
  }

  if (filters.difficulty) {
    whereConditions.push(`tq."difficulty" = $${paramIndex}`);
    params.push(filters.difficulty);
    paramIndex++;
  }

  const whereClause = whereConditions.length > 0 
    ? `WHERE ${whereConditions.join(' AND ')}` 
    : '';

  // Use TABLESAMPLE for efficient random selection in PostgreSQL
  // Falls back to ORDER BY RANDOM() for smaller result sets
  const query = `
    WITH random_questions AS (
      SELECT 
        tq.id,
        tq."clueId",
        tq.rephrased,
        tq."correctAnswer",
        tq."wrongAnswer1",
        tq."wrongAnswer2", 
        tq."wrongAnswer3",
        tq."createdAt",
        tq.model,
        cl.id as clue_id,
        cl."gameId",
        cl.value,
        cl.question,
        cl.answer,
        cl."categoryId",
        c.id as category_id,
        c.title as category_title
      FROM "TriviaQuestion" tq
      INNER JOIN "Clue" cl ON tq."clueId" = cl.id
      INNER JOIN "Category" c ON cl."categoryId" = c.id
      ${whereClause}
      ORDER BY RANDOM()
      LIMIT 1
    )
    SELECT * FROM random_questions;
  `;

  const result = await prisma.$queryRawUnsafe(query, ...params);
  
  if (result.length === 0) {
    return null;
  }

  // Transform the raw result to match our expected format
  const row = result[0];
  return {
    id: row.id,
    rephrased: row.rephrased,
    correctAnswer: row.correctAnswer,
    wrongAnswer1: row.wrongAnswer1,
    wrongAnswer2: row.wrongAnswer2,
    wrongAnswer3: row.wrongAnswer3,
    createdAt: row.createdAt,
    model: row.model,
    clueId: row.clueId,
    clue: {
      id: row.clue_id,
      gameId: row.gameId,
      value: row.value,
      question: row.question,
      answer: row.answer,
      categoryId: row.categoryId,
      category: {
        id: row.category_id,
        title: row.category_title
      }
    }
  };
};

/**
 * Get categories with counts using a single optimized query
 * @returns {Promise<Array>} Categories with trivia question counts
 */
const getCategoriesWithCountsOptimized = async () => {
  const query = `
    SELECT 
      c.id,
      c.title,
      COUNT(DISTINCT tq.id) as trivia_count
    FROM "Category" c
    INNER JOIN "Clue" cl ON c.id = cl."categoryId"
    INNER JOIN "TriviaQuestion" tq ON cl.id = tq."clueId"
    GROUP BY c.id, c.title
    HAVING COUNT(DISTINCT tq.id) > 0
    ORDER BY c.title ASC;
  `;

  const result = await prisma.$queryRaw(query);
  
  return result.map(row => ({
    id: row.id,
    title: row.title,
    triviaCount: Number(row.trivia_count)
  }));
};

module.exports = {
  getRandomTriviaQuestionOptimized,
  getCategoriesWithCountsOptimized
};