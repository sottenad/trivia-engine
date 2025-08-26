// Trivia Card Component

import { TriviaQuestion } from '@/types/api';

interface TriviaCardProps {
  question: TriviaQuestion;
  selectedOption: string | null;
  showAnswer: boolean;
  onOptionSelect: (option: string) => void;
  onNextQuestion: () => void;
  loading?: boolean;
}

export default function TriviaCard({
  question,
  selectedOption,
  showAnswer,
  onOptionSelect,
  onNextQuestion,
  loading = false
}: TriviaCardProps) {
  if (loading) {
    return (
      <div className="bg-gray-800 rounded-xl shadow-2xl overflow-hidden gradient-border max-w-3xl mx-auto">
        <div className="p-6 md:p-8">
          <div className="animate-pulse">
            <div className="h-8 bg-gray-700 rounded w-3/4 mb-6"></div>
            <div className="h-20 bg-gray-700 rounded mb-6"></div>
            <div className="space-y-3">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="h-14 bg-gray-700 rounded"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-gray-800 rounded-xl shadow-2xl overflow-hidden gradient-border max-w-3xl mx-auto">
      <div className="p-6 md:p-8">
        <h2 className="text-2xl font-bold mb-6 gradient-text">Try a Random Trivia Question</h2>
        
        <div className="mb-4">
          <span className="inline-block px-3 py-1 bg-purple-600/20 text-purple-300 rounded-full text-sm font-medium">
            {question.category}
          </span>
        </div>
        
        <div className="mb-6 p-5 bg-gray-700/50 rounded-lg border border-gray-600">
          <p className="text-xl font-medium text-gray-100">{question.question}</p>
        </div>
        
        <div className="space-y-3 mb-6">
          {question.options.map((option, index) => (
            <button 
              key={index} 
              onClick={() => onOptionSelect(option)}
              disabled={showAnswer}
              className={`w-full p-4 rounded-lg border text-left transition-all ${
                selectedOption === option && showAnswer
                  ? option === question.correctAnswer
                    ? 'bg-green-500/20 border-green-500 text-green-200'
                    : 'bg-red-500/20 border-red-500 text-red-200'
                  : selectedOption === option
                  ? 'bg-purple-500/20 border-purple-500 text-purple-200'
                  : 'bg-gray-700 border-gray-600 hover:bg-gray-600 hover:border-gray-500 disabled:hover:bg-gray-700 disabled:hover:border-gray-600 disabled:cursor-not-allowed'
              }`}
              aria-label={`Option ${index + 1}: ${option}`}
            >
              {option}
              {showAnswer && option === question.correctAnswer && (
                <span className="ml-2 inline-flex items-center" aria-label="Correct answer">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </span>
              )}
            </button>
          ))}
        </div>
        
        {showAnswer && (
          <div className="bg-gray-700 p-4 rounded-lg border border-gray-600 mb-6">
            <p className="font-medium">
              Correct Answer: <span className="text-green-400">{question.correctAnswer}</span>
            </p>
          </div>
        )}
        
        <div className="mt-6 flex justify-center">
          <button 
            onClick={onNextQuestion}
            className="px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg font-semibold hover:from-purple-700 hover:to-blue-700 transition-colors text-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-800"
          >
            Get Another Question
          </button>
        </div>
        
        <div className="mt-4 text-center text-sm text-gray-500">
          Powered by trivia-engine.com API
        </div>
      </div>
    </div>
  );
}