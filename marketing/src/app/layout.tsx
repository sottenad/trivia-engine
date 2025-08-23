import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Trivia Engine API - 100,000+ Trivia Questions",
  description: "Access over 100,000 trivia questions through our easy-to-use API",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark scroll-smooth">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-gray-900 text-gray-100`}
      >
        <header className="sticky top-0 z-50 backdrop-blur-md bg-gray-800/80 border-b border-purple-500/20">
          <div className="container mx-auto flex justify-between items-center py-4 px-6">
            <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-blue-500">Trivia Engine</h1>
           
          </div>
        </header>
        <main>
          {children}
        </main>
        <footer className="bg-gray-800 border-t border-purple-500/20 py-6 px-4">
          <div className="container mx-auto text-center text-gray-400">
            <p>© {new Date().getFullYear()} Trivia Engine. All rights reserved.</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
