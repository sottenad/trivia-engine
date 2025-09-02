/** @type {import('next').NextConfig} */
const nextConfig = {
  // Output as static export - no Node.js server needed
  output: 'export',
  
  // Disable source maps in production to save memory
  productionBrowserSourceMaps: false,
  
  // For static export with client-side routing
  trailingSlash: true,
};

export default nextConfig;
