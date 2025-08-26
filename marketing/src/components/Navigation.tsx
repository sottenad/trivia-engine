'use client';

import Link from 'next/link';
import { useState, useEffect } from 'react';

const navItems = [
  { href: '/', label: 'Home' },
  { href: '#about', label: 'About' },
  { href: '#documentation', label: 'Documentation' },
  { href: '#contact', label: 'Contact' },
];

export default function Navigation() {
  const [isOpen, setIsOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 10);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <nav 
      className={`fixed w-full top-0 z-50 transition-all duration-300 ${
        isScrolled 
          ? 'bg-gray-900/95 backdrop-blur-md shadow-lg' 
          : 'bg-transparent'
      }`}
    >
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <Link 
            href="/" 
            className="text-xl font-bold gradient-text hover:opacity-80 transition-opacity"
          >
            Trivia Engine
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-8">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="text-gray-300 hover:text-white transition-colors duration-200 font-medium"
              >
                {item.label}
              </Link>
            ))}
            <Link
              href="https://api.trivia-engine.com"
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg font-medium hover:from-purple-700 hover:to-blue-700 transition-all duration-200 text-white"
            >
              Get API Key
            </Link>
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden focus:outline-none focus:ring-2 focus:ring-purple-500 rounded-lg p-2"
            aria-label="Toggle navigation menu"
            aria-expanded={isOpen}
          >
            <svg
              className="h-6 w-6 text-gray-300"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="2"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              {isOpen ? (
                <path d="M6 18L18 6M6 6l12 12" />
              ) : (
                <path d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>

        {/* Mobile Navigation */}
        <div
          className={`md:hidden transition-all duration-300 ease-in-out ${
            isOpen 
              ? 'max-h-96 opacity-100' 
              : 'max-h-0 opacity-0 overflow-hidden'
          }`}
        >
          <div className="py-4 space-y-2">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setIsOpen(false)}
                className="block px-4 py-2 text-gray-300 hover:text-white hover:bg-gray-800 rounded-lg transition-colors duration-200"
              >
                {item.label}
              </Link>
            ))}
            <Link
              href="https://api.trivia-engine.com"
              target="_blank"
              rel="noopener noreferrer"
              className="block px-4 py-2 text-center bg-gradient-to-r from-purple-600 to-blue-600 rounded-lg font-medium hover:from-purple-700 hover:to-blue-700 transition-all duration-200 text-white"
            >
              Get API Key
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}