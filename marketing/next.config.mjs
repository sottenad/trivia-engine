/** @type {import('next').NextConfig} */
const nextConfig = {
  // Output standalone for self-contained deployments
  output: 'standalone',
  
  // Disable source maps in production to save memory
  productionBrowserSourceMaps: false,
};

export default nextConfig;
