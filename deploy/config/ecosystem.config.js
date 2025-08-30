module.exports = {
  apps: [
    {
      // API Server
      name: 'trivia-api',
      script: './app/api/index.js',
      cwd: '/home/trivia/trivia-engine',
      instances: 'max', // Use all available CPU cores
      exec_mode: 'cluster',
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'development',
        PORT: 3003,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3003,
      },
      error_file: '/home/trivia/logs/api-error.log',
      out_file: '/home/trivia/logs/api-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      // Graceful shutdown
      kill_timeout: 5000,
      wait_ready: true,
      listen_timeout: 10000,
    },
    {
      // Marketing Site (Next.js)
      name: 'trivia-marketing',
      script: 'npm',
      args: 'start',
      cwd: '/home/trivia/trivia-engine/marketing',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: '/home/trivia/logs/marketing-error.log',
      out_file: '/home/trivia/logs/marketing-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
    },
    {
      // MCP Server (Optional - only if you want to run it continuously)
      name: 'trivia-mcp',
      script: './mcp/build/index.js',
      cwd: '/home/trivia/trivia-engine',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'development',
      },
      env_production: {
        NODE_ENV: 'production',
      },
      error_file: '/home/trivia/logs/mcp-error.log',
      out_file: '/home/trivia/logs/mcp-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      // MCP might not need to run continuously
      // You can disable it by setting:
      // autorestart: false,
    },
  ],

  // PM2 Deploy Configuration (optional)
  deploy: {
    production: {
      user: 'trivia',
      host: 'trivia-engine.com',
      ref: 'origin/main',
      repo: 'git@github.com:sottenad/trivia-engine.git',
      path: '/home/trivia/trivia-engine',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': '',
    },
  },
};