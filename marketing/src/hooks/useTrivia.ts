// Custom React hooks for trivia functionality

import { useState, useEffect, useCallback } from 'react';
import { apiClient } from '@/lib/api';
import { TriviaQuestion } from '@/types/api';

export interface UseTriviaState {
  question: TriviaQuestion | null;
  loading: boolean;
  error: string | null;
  selectedOption: string | null;
  showAnswer: boolean;
}

export interface UseTriviaActions {
  fetchRandomQuestion: (category?: string) => Promise<void>;
  selectOption: (option: string) => void;
  resetQuestion: () => void;
}

export function useTrivia(initialCategory?: string): UseTriviaState & UseTriviaActions {
  const [question, setQuestion] = useState<TriviaQuestion | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [showAnswer, setShowAnswer] = useState(false);

  const fetchRandomQuestion = useCallback(async (category?: string) => {
    setLoading(true);
    setError(null);
    setSelectedOption(null);
    setShowAnswer(false);

    try {
      const response = await apiClient.getRandomTrivia(category);
      
      if (response.success && response.data?.trivia) {
        setQuestion(response.data.trivia);
      } else {
        throw new Error('Failed to fetch trivia question');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred';
      setError(errorMessage);
      
      // Use fallback questions if API fails
      setQuestion(getFallbackQuestion());
    } finally {
      setLoading(false);
    }
  }, []);

  const selectOption = useCallback((option: string) => {
    setSelectedOption(option);
    setShowAnswer(true);
  }, []);

  const resetQuestion = useCallback(() => {
    setSelectedOption(null);
    setShowAnswer(false);
  }, []);

  useEffect(() => {
    fetchRandomQuestion(initialCategory);
  }, [initialCategory, fetchRandomQuestion]);

  return {
    question,
    loading,
    error,
    selectedOption,
    showAnswer,
    fetchRandomQuestion,
    selectOption,
    resetQuestion,
  };
}

// Fallback questions when API is unavailable
function getFallbackQuestion(): TriviaQuestion {
  const fallbackQuestions: TriviaQuestion[] = [
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

  return fallbackQuestions[Math.floor(Math.random() * fallbackQuestions.length)];
}