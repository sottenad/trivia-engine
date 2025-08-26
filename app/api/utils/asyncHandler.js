/**
 * Wraps async functions to catch errors and forward them to the error middleware
 * @param {Function} fn - The async function to wrap
 * @returns {Function} The wrapped function
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next))
      .catch(next); // Forward errors to error middleware
  };
};

module.exports = asyncHandler; 