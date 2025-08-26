const { prisma } = require('../../config/database');
const { ApiError } = require('../middleware/errorMiddleware');

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

    // Use Prisma's raw query for efficient random selection
    // This is much more efficient than count + skip approach
    const triviaQuestions = await prisma.triviaQuestion.findMany({
      where: whereClause,
      include: {
        clue: {
          include: {
            category: true
          }
        }
      },
      take: 1,
      orderBy: {
        id: 'asc'
      },
      skip: Math.floor(Math.random() * 1000) // Random offset within reasonable range
    });

    // If no result with random offset, try without offset
    let triviaQuestion = triviaQuestions[0];
    
    if (!triviaQuestion) {
      triviaQuestion = await prisma.triviaQuestion.findFirst({
        where: whereClause,
        include: {
          clue: {
            include: {
              category: true
            }
          }
        }
      });
    }

    if (!triviaQuestion) {
      throw new ApiError(404, 'No trivia question found');
    }

    // Format the response using the helper function
    res.json({
      success: true,
      data: {
        trivia: formatTriviaQuestion(triviaQuestion)
      }
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
      throw new ApiError(404, 'Trivia question not found');
    }

    // Format the response using the helper function
    res.json({
      success: true,
      data: {
        trivia: formatTriviaQuestion(triviaQuestion)
      }
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
      throw new ApiError(400, 'Invalid limit or offset parameters');
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
      throw new ApiError(404, 'Category not found');
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
      data: {
        category: category.title,
        total: totalQuestions,
        count: triviaQuestions.length,
        offset: offsetInt,
        limit: limitInt,
        trivia: triviaQuestions.map(question => formatTriviaQuestion(question))
      }
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
    // Get categories with trivia question counts using aggregation
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
      select: {
        id: true,
        title: true,
        _count: {
          select: {
            clues: {
              where: {
                triviaQuestions: {
                  some: {}
                }
              }
            }
          }
        }
      },
      orderBy: { title: 'asc' }
    });

    // Transform the response
    const categoriesWithCount = categories.map(category => ({
      id: category.id,
      title: category.title,
      triviaCount: category._count.clues
    }));

    res.json({
      success: true,
      data: {
        count: categoriesWithCount.length,
        categories: categoriesWithCount
      }
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
      throw new ApiError(400, 'Search query is required');
    }

    // Parse limit and offset to integers
    const limitInt = parseInt(limit);
    const offsetInt = parseInt(offset);

    // Validate limit and offset
    if (isNaN(limitInt) || isNaN(offsetInt) || limitInt < 1 || offsetInt < 0) {
      throw new ApiError(400, 'Invalid limit or offset parameters');
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
      data: {
        query,
        total: totalMatches,
        count: triviaQuestions.length,
        offset: offsetInt,
        limit: limitInt,
        trivia: triviaQuestions.map(question => formatTriviaQuestion(question))
      }
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