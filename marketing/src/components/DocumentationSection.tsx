'use client';

import { useState } from 'react';

interface CodeExample {
  language: string;
  code: string;
}

export default function DocumentationSection() {
  const [activeTab, setActiveTab] = useState('javascript');

  const codeExamples: Record<string, CodeExample> = {
    javascript: {
      language: 'JavaScript',
      code: `// Fetch a random trivia question
const response = await fetch('https://api.trivia-engine.com/api/v1/trivia/random', {
  headers: {
    'X-API-Key': 'your-api-key-here'
  }
});

const data = await response.json();
console.log(data.trivia);
// Output: { question, options, correctAnswer, category }`
    },
    python: {
      language: 'Python',
      code: `import requests

# Fetch a random trivia question
response = requests.get(
    'https://api.trivia-engine.com/api/v1/trivia/random',
    headers={'X-API-Key': 'your-api-key-here'}
)

data = response.json()
print(data['trivia'])
# Output: { question, options, correctAnswer, category }`
    },
    curl: {
      language: 'cURL',
      code: `# Fetch a random trivia question
curl -X GET https://api.trivia-engine.com/api/v1/trivia/random \\
  -H "X-API-Key: your-api-key-here"

# Response:
{
  "success": true,
  "data": {
    "trivia": {
      "question": "...",
      "options": [...],
      "correctAnswer": "...",
      "category": "..."
    }
  }
}`
    }
  };

  const endpoints = [
    {
      method: 'GET',
      path: '/trivia/random',
      description: 'Get a random trivia question'
    },
    {
      method: 'GET',
      path: '/trivia/:id',
      description: 'Get a specific trivia question by ID'
    },
    {
      method: 'GET',
      path: '/trivia/categories',
      description: 'List all available categories'
    },
    {
      method: 'GET',
      path: '/trivia/category/:name',
      description: 'Get questions from a specific category'
    },
    {
      method: 'GET',
      path: '/trivia/search?query=term',
      description: 'Search for questions containing a term'
    }
  ];

  return (
    <section id="documentation" className="py-20 px-4">
      <div className="container mx-auto max-w-6xl">
        <div className="text-center mb-12">
          <h2 className="text-4xl md:text-5xl font-bold mb-4 gradient-text">
            Documentation
          </h2>
          <p className="text-xl text-gray-400 max-w-3xl mx-auto">
            Everything you need to integrate Trivia Engine into your application.
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-12">
          {/* Endpoints List */}
          <div>
            <h3 className="text-2xl font-bold mb-6">API Endpoints</h3>
            <div className="space-y-4">
              {endpoints.map((endpoint, index) => (
                <div 
                  key={index}
                  className="bg-gray-800 rounded-lg p-4 border border-gray-700"
                >
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-3">
                      <span className={`px-3 py-1 rounded text-xs font-bold ${
                        endpoint.method === 'GET' 
                          ? 'bg-green-600/20 text-green-400' 
                          : 'bg-blue-600/20 text-blue-400'
                      }`}>
                        {endpoint.method}
                      </span>
                      <code className="text-gray-300 font-mono text-sm">
                        {endpoint.path}
                      </code>
                    </div>
                  </div>
                  <p className="text-gray-400 text-sm">
                    {endpoint.description}
                  </p>
                </div>
              ))}
            </div>

            <div className="mt-8">
              <a 
                href="/api-docs"
                className="inline-flex items-center text-purple-400 hover:text-purple-300 transition-colors"
              >
                View Full API Documentation
                <svg className="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </a>
            </div>
          </div>

          {/* Code Examples */}
          <div>
            <h3 className="text-2xl font-bold mb-6">Quick Start</h3>
            
            {/* Language Tabs */}
            <div className="flex space-x-2 mb-4">
              {Object.keys(codeExamples).map((lang) => (
                <button
                  key={lang}
                  onClick={() => setActiveTab(lang)}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                    activeTab === lang
                      ? 'bg-purple-600 text-white'
                      : 'bg-gray-800 text-gray-400 hover:text-white'
                  }`}
                >
                  {codeExamples[lang].language}
                </button>
              ))}
            </div>

            {/* Code Block */}
            <div className="bg-gray-900 rounded-lg overflow-hidden border border-gray-700">
              <pre className="p-6 overflow-x-auto">
                <code className="text-sm text-gray-300 font-mono">
                  {codeExamples[activeTab].code}
                </code>
              </pre>
            </div>

            <div className="mt-6 p-4 bg-blue-900/20 border border-blue-500/20 rounded-lg">
              <p className="text-sm text-blue-300">
                <strong>Note:</strong> Replace <code className="bg-gray-800 px-1 py-0.5 rounded">your-api-key-here</code> with 
                your actual API key from the developer portal.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}