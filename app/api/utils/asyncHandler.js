/**
 * Wraps async functions to catch errors and forward them to the error middleware
 * @param {Function} fn - The async function to wrap
 * @returns {Function} The wrapped function
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next))
      .catch((error) => {
        console.error('AsyncHandler caught error:', error);
        return res.status(500).json({
          success: false,
          error: error.message || 'Server Error'
        });
      });
  };
};

module.exports = asyncHandler; 