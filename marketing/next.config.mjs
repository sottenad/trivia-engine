/** @type {import('next').NextConfig} */
const nextConfig = {
  // Reduce memory usage during build
  experimental: {
    // Reduce memory usage with build worker
    workerThreads: false,
    cpus: 1,
  },
  
  // Disable source maps in production to save memory
  productionBrowserSourceMaps: false,
  
  // Minimize memory usage
  swcMinify: true,
  
  // Output standalone for smaller deployments
  output: 'standalone',
};

export default nextConfig;
