'use client';

import { useTrivia } from '@/hooks/useTrivia';
import TriviaCard from '@/components/TriviaCard';
import AboutSection from '@/components/AboutSection';
import DocumentationSection from '@/components/DocumentationSection';
import ContactSection from '@/components/ContactSection';

export default function Home() {
  const {
    question,
    loading,
    error,
    selectedOption,
    showAnswer,
    fetchRandomQuestion,
    selectOption,
  } = useTrivia();

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
          {error ? (
            <div className="max-w-3xl mx-auto">
              <div className="bg-red-900/20 border border-red-500/20 rounded-lg p-6 text-center">
                <p className="text-red-400">Unable to connect to the API. Using demo questions.</p>
              </div>
            </div>
          ) : null}
          
          {question && (
            <TriviaCard
              question={question}
              selectedOption={selectedOption}
              showAnswer={showAnswer}
              onOptionSelect={selectOption}
              onNextQuestion={() => fetchRandomQuestion()}
              loading={loading}
            />
          )}
        </div>
      </section>

      {/* About Section */}
      <AboutSection />

      {/* Documentation Section */}
      <DocumentationSection />

      {/* Contact Section */}
      <ContactSection />
    </div>
  );
}
