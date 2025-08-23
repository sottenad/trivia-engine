const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Helper function to format trivia question response
 * @param {Object} question - The trivia question object from prisma
 * @returns {Object} - Formatted trivia question object
 */
const formatTriviaQuestion = (question) => {
  return {
    id: question.id,
    question: question.rephrased,
    options: [
      question.correctAnswer,
      question.wrongAnswer1,
      question.wrongAnswer2,
      question.wrongAnswer3
    ].sort(() => Math.random() - 0.5), // Shuffle the options
    correctAnswer: question.correctAnswer,
    category: question.clue.category.title,
    clue: question.clue,
  };
};

/**
 * @desc    Get random trivia question
 * @route   GET /api/trivia/random
 * @access  Private (requires API key)
 */
const getRandomTriviaQuestion = async (req, res, next) => {
  try {
    // Get query parameters
    const { category, difficulty } = req.query;
    
    // Build where clause for filtering
    const whereClause = {};
    if (category) {
      whereClause.clue = {
        category: {
          title: {
            contains: category,
            mode: 'insensitive'
          }
        }
      };
    }
    
    // Difficulty filter (if implemented in your schema)
    if (difficulty) {
      whereClause.difficulty = difficulty;
    }

    // Count total matching questions to get a random offset
    const totalQuestions = await prisma.triviaQuestion.count({
      where: whereClause
    });

    if (totalQuestions === 0) {
      return res.status(404).json({
        success: false,
        message: 'No trivia questions found matching the criteria'
      });
    }

    // Get a random offset
    const randomOffset = Math.floor(Math.random() * totalQuestions);

    // Fetch a random question
    const triviaQuestion = await prisma.triviaQuestion.findFirst({
      skip: randomOffset,
      where: whereClause,
      include: {
        clue: {
          include: {
            category: true
          }
        }
      }
    });

    if (!triviaQuestion) {
      return res.status(404).json({
        success: false,
        message: 'No trivia question found'
      });
    }

    // Format the response using the helper function
    res.json({
      success: true,
      trivia: formatTriviaQuestion(triviaQuestion)
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get trivia question by ID
 * @route   GET /api/trivia/:id
 * @access  Private (requires API key)
 */
const getTriviaQuestionById = async (req, res, next) => {
  try {
    const triviaId = parseInt(req.params.id);

    const triviaQuestion = await prisma.triviaQuestion.findUnique({
      where: { id: triviaId },
      include: {
        clue: {
          include: {
            category: true
          }
        }
      }
    });

    if (!triviaQuestion) {
      res.status(404);
      throw new Error('Trivia question not found');
    }

    // Format the response using the helper function
    res.json({
      success: true,
      trivia: formatTriviaQuestion(triviaQuestion)
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get trivia questions by category
 * @route   GET /api/trivia/category/:categoryTitle
 * @access  Private (requires API key)
 */
const getTriviaByCategory = async (req, res, next) => {
  try {
    const { categoryTitle } = req.params;
    const { limit = 10, offset = 0 } = req.query;

    // Parse limit and offset to integers
    const limitInt = parseInt(limit);
    const offsetInt = parseInt(offset);

    // Validate limit and offset
    if (isNaN(limitInt) || isNaN(offsetInt) || limitInt < 1 || offsetInt < 0) {
      res.status(400);
      throw new Error('Invalid limit or offset parameters');
    }

    // Get category
    const category = await prisma.category.findFirst({
      where: {
        title: {
          contains: categoryTitle,
          mode: 'insensitive'
        }
      }
    });

    if (!category) {
      res.status(404);
      throw new Error('Category not found');
    }

    // Count total questions in this category
    const totalQuestions = await prisma.triviaQuestion.count({
      where: {
        clue: {
          categoryId: category.id
        }
      }
    });

    // Get questions
    const triviaQuestions = await prisma.triviaQuestion.findMany({
      where: {
        clue: {
          categoryId: category.id
        }
      },
      include: {
        clue: {
          include: {
            category: true
          }
        }
      },
      take: limitInt,
      skip: offsetInt,
      orderBy: { id: 'asc' }
    });

    // Format the response using the helper function
    res.json({
      success: true,
      category: category.title,
      total: totalQuestions,
      count: triviaQuestions.length,
      offset: offsetInt,
      limit: limitInt,
      trivia: triviaQuestions.map(question => formatTriviaQuestion(question))
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    List available categories
 * @route   GET /api/trivia/categories
 * @access  Private (requires API key)
 */
const getCategories = async (req, res, next) => {
  try {
    // Get categories that have associated trivia questions
    const categories = await prisma.category.findMany({
      where: {
        clues: {
          some: {
            triviaQuestions: {
              some: {}
            }
          }
        }
      },
      orderBy: { title: 'asc' }
    });

    // Get count of trivia questions for each category
    const categoriesWithCount = await Promise.all(
      categories.map(async (category) => {
        const count = await prisma.triviaQuestion.count({
          where: {
            clue: {
              categoryId: category.id
            }
          }
        });

        return {
          id: category.id,
          title: category.title,
          triviaCount: count
        };
      })
    );

    res.json({
      success: true,
      count: categoriesWithCount.length,
      categories: categoriesWithCount
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Search trivia questions
 * @route   GET /api/trivia/search
 * @access  Private (requires API key)
 */
const searchTrivia = async (req, res, next) => {
  try {
    const { query, limit = 10, offset = 0 } = req.query;

    if (!query || query.trim() === '') {
      res.status(400);
      throw new Error('Search query is required');
    }

    // Parse limit and offset to integers
    const limitInt = parseInt(limit);
    const offsetInt = parseInt(offset);

    // Validate limit and offset
    if (isNaN(limitInt) || isNaN(offsetInt) || limitInt < 1 || offsetInt < 0) {
      res.status(400);
      throw new Error('Invalid limit or offset parameters');
    }

    // Search in question, correct answer, or clue text
    const whereClause = {
      OR: [
        { question: { contains: query, mode: 'insensitive' } },
        { correctAnswer: { contains: query, mode: 'insensitive' } },
        { clue: { text: { contains: query, mode: 'insensitive' } } },
        { clue: { answer: { contains: query, mode: 'insensitive' } } },
        { clue: { category: { title: { contains: query, mode: 'insensitive' } } } }
      ]
    };

    // Count total matches
    const totalMatches = await prisma.triviaQuestion.count({
      where: whereClause
    });

    // Get matching questions
    const triviaQuestions = await prisma.triviaQuestion.findMany({
      where: whereClause,
      include: {
        clue: {
          include: {
            category: true
          }
        }
      },
      take: limitInt,
      skip: offsetInt,
      orderBy: { id: 'asc' }
    });

    // Format the response using the helper function
    res.json({
      success: true,
      query,
      total: totalMatches,
      count: triviaQuestions.length,
      offset: offsetInt,
      limit: limitInt,
      trivia: triviaQuestions.map(question => formatTriviaQuestion(question))
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getRandomTriviaQuestion,
  getTriviaQuestionById,
  getTriviaByCategory,
  getCategories,
  searchTrivia
}; 