export default function AboutSection() {
  const features = [
    {
      title: "100,000+ Questions",
      description: "Access a vast database of trivia questions across hundreds of categories.",
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
        </svg>
      )
    },
    {
      title: "RESTful API",
      description: "Simple, intuitive REST API that's easy to integrate into any application.",
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
      )
    },
    {
      title: "Real-time Updates",
      description: "Our database is constantly growing with new questions and categories.",
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
        </svg>
      )
    },
    {
      title: "Rate Limiting",
      description: "Flexible rate limiting options to match your application's needs.",
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      )
    }
  ];

  return (
    <section id="about" className="py-20 px-4 bg-gray-800/50">
      <div className="container mx-auto max-w-6xl">
        <div className="text-center mb-12">
          <h2 className="text-4xl md:text-5xl font-bold mb-4 gradient-text">
            Why Choose Trivia Engine?
          </h2>
          <p className="text-xl text-gray-400 max-w-3xl mx-auto">
            Built for developers, by developers. Our API provides everything you need 
            to create engaging trivia experiences.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-8">
          {features.map((feature, index) => (
            <div 
              key={index}
              className="bg-gray-800 rounded-xl p-6 border border-gray-700 hover:border-purple-500/50 transition-colors duration-300"
            >
              <div className="flex items-start space-x-4">
                <div className="flex-shrink-0 p-3 bg-purple-600/20 rounded-lg text-purple-400">
                  {feature.icon}
                </div>
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-white">
                    {feature.title}
                  </h3>
                  <p className="text-gray-400">
                    {feature.description}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-16 text-center">
          <div className="inline-flex flex-col sm:flex-row gap-4">
            <a 
              href="#documentation"
              className="px-8 py-3 bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg font-semibold hover:from-purple-700 hover:to-blue-700 transition-colors duration-200 text-white"
            >
              View Documentation
            </a>
            <a 
              href="https://api.trivia-engine.com"
              target="_blank"
              rel="noopener noreferrer"
              className="px-8 py-3 border border-gray-600 rounded-lg font-semibold hover:border-gray-500 hover:bg-gray-800 transition-all duration-200"
            >
              Get Started Free
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}