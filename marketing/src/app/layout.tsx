import type { Metadata } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import Navigation from '@/components/Navigation';
import Footer from '@/components/Footer';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Trivia Engine - The Ultimate Trivia API',
  description: 'Access over 100,000 trivia questions with our powerful API. Perfect for game developers, educators, and trivia enthusiasts.',
  keywords: 'trivia api, quiz api, trivia questions, game development, education api',
  authors: [{ name: 'Trivia Engine Team' }],
  openGraph: {
    title: 'Trivia Engine - The Ultimate Trivia API',
    description: 'Access over 100,000 trivia questions with our powerful API.',
    type: 'website',
    url: 'https://trivia-engine.com',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Trivia Engine API',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Trivia Engine - The Ultimate Trivia API',
    description: 'Access over 100,000 trivia questions with our powerful API.',
    images: ['/og-image.png'],
  },
  robots: {
    index: true,
    follow: true,
  },
  viewport: {
    width: 'device-width',
    initialScale: 1,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${jetbrainsMono.variable}`}>
      <body className={`${inter.className} bg-gray-900 text-gray-100 antialiased`}>
        <Navigation />
        <main className="min-h-screen pt-16">
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}