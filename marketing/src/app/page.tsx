'use client';

import { useState, useEffect } from 'react';

interface TriviaQuestion {
  id: number;
  question: string;
  options: string[];
  correctAnswer: string;
  category: string;
}

export default function Home() {
  const [triviaQuestion, setTriviaQuestion] = useState<TriviaQuestion | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [showAnswer, setShowAnswer] = useState(false);

  const fetchRandomTrivia = async () => {
    setLoading(true);
    setSelectedOption(null);
    setShowAnswer(false);
    
    try {
      // Use the actual API endpoint
      const response = await fetch('https://api.trivia-engine.com/api/trivia/random', {
        method: 'GET',
        headers: {
          'x-api-key': 'a8787d23-b53d-474f-8ecb-7ab1b7d5f2eb',
          'Content-Type': 'application/json'
        }
      });
      
      if (!response.ok) {
        throw new Error('Failed to fetch trivia question');
      }
      
      const data = await response.json();
      if (data.success && data.trivia) {
        setTriviaQuestion(data.trivia);
      } else {
        // Fallback to sample questions if the API doesn't return expected format
        fallbackToSampleQuestion();
      }
      
      setError(null);
    } catch (err) {
      console.error('Error fetching trivia:', err);
      // Fallback to sample questions if the API request fails
      fallbackToSampleQuestion();
    } finally {
      setLoading(false);
    }
  };
  
  const fallbackToSampleQuestion = () => {
    // Sample trivia questions to rotate through as fallback
    const sampleQuestions = [
      {
        id: 1,
        question: "Which of these terms refers to a writing under a fictitious name?",
        options: ["pen name", "pseudonym", "alias", "nom de plume"],
        correctAnswer: "pseudonym",
        category: "LITERATURE"
      },
      {
        id: 2,
        question: "Which U.S. state is known as the 'Sunshine State'?",
        options: ["California", "Florida", "Hawaii", "Arizona"],
        correctAnswer: "Florida",
        category: "GEOGRAPHY"
      },
      {
        id: 3, 
        question: "What is the capital of France?",
        options: ["London", "Berlin", "Paris", "Rome"],
        correctAnswer: "Paris",
        category: "WORLD CAPITALS"
      },
      {
        id: 4,
        question: "Which element has the chemical symbol 'Au'?",
        options: ["Silver", "Gold", "Aluminum", "Argon"],
        correctAnswer: "Gold",
        category: "CHEMISTRY"
      },
      {
        id: 5,
        question: "Which planet is known as the 'Red Planet'?",
        options: ["Venus", "Jupiter", "Mars", "Mercury"],
        correctAnswer: "Mars",
        category: "ASTRONOMY"
      }
    ];
    
    const randomIndex = Math.floor(Math.random() * sampleQuestions.length);
    setTriviaQuestion(sampleQuestions[randomIndex]);
  };

  const handleOptionSelect = (option: string) => {
    setSelectedOption(option);
    setShowAnswer(true);
  };

  useEffect(() => {
    fetchRandomTrivia();
  }, []);

  return (
    <div className="min-h-screen">
      {/* Hero Section with Demo Integrated */}
      <section id="demo" className="relative py-20 px-4 hero-gradient">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-20 left-10 w-64 h-64 bg-purple-600 rounded-full mix-blend-multiply filter blur-3xl opacity-10 float"></div>
          <div className="absolute bottom-20 right-10 w-72 h-72 bg-blue-600 rounded-full mix-blend-multiply filter blur-3xl opacity-10 float float-delay-1"></div>
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-indigo-600 rounded-full mix-blend-multiply filter blur-3xl opacity-5 float float-delay-2"></div>
        </div>
        
        <div className="container mx-auto max-w-6xl z-10 relative">
          <div className="text-center mb-10">
            <h1 className="text-5xl md:text-7xl font-bold mb-6 gradient-text">The Ultimate Trivia API</h1>
            <p className="text-xl md:text-2xl mb-8 text-gray-300">Access over <span className="font-bold text-purple-400">100,000</span> trivia questions with a simple API call.</p>
          </div>
          
          {/* Featured Demo Card */}
          <div className="bg-gray-800 rounded-xl shadow-2xl overflow-hidden gradient-border max-w-3xl mx-auto">
            <div className="p-6 md:p-8">
              <h2 className="text-2xl font-bold mb-6 gradient-text">Try a Random Trivia Question</h2>
              
              {loading ? (
                <div className="flex justify-center items-center h-56">
                  <div className="animate-spin rounded-full h-12 w-12 border-4 border-purple-500 border-t-transparent"></div>
                </div>
              ) : error ? (
                <div className="text-red-400 text-center p-4 bg-red-900/20 rounded-lg">
                  {error}
                </div>
              ) : triviaQuestion ? (
                <div>
                  <div className="mb-6 p-5 bg-gray-700/50 rounded-lg border border-gray-600">
                    <p className="text-xl font-medium text-gray-100">{triviaQuestion.question}</p>
                    
                  </div>
                  
                  <div className="space-y-3 mb-6">
                    {triviaQuestion.options.map((option, index) => (
                      <button 
                        key={index} 
                        onClick={() => handleOptionSelect(option)}
                        disabled={showAnswer}
                        className={`w-full p-4 rounded-lg border text-left transition-all ${
                          selectedOption === option && showAnswer
                            ? option === triviaQuestion.correctAnswer
                              ? 'bg-green-500/20 border-green-500 text-green-200'
                              : 'bg-red-500/20 border-red-500 text-red-200'
                            : selectedOption === option
                            ? 'bg-purple-500/20 border-purple-500 text-purple-200'
                            : 'bg-gray-700 border-gray-600 hover:bg-gray-600 hover:border-gray-500'
                        }`}
                      >
                        {option}
                        {showAnswer && option === triviaQuestion.correctAnswer && (
                          <span className="ml-2 inline-flex items-center">
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
                        Correct Answer: <span className="text-green-400">{triviaQuestion.correctAnswer}</span>
                      </p>
                    </div>
                  )}
                </div>
              ) : (
                <div className="text-center p-8 bg-gray-700/30 rounded-lg">
                  No question available
                </div>
              )}
              
              <div className="mt-6 flex justify-center">
                <button 
                  onClick={fetchRandomTrivia}
                  className="px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg font-semibold hover:from-purple-700 hover:to-blue-700 transition-colors text-white"
                >
                  Get Another Question
                </button>
              </div>
              
              <div className="mt-4 text-center text-sm text-gray-500">
                Powered by trivia-engine.com API
              </div>
            </div>
          </div>
        </div>
      </section>

   
     
    </div>
  );
}
