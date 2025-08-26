module.exports = {
  apps: [
    {
      name: 'trivia-api',
      script: './app/api/index.js',
      cwd: '/home/trivia/trivia-engine',
      instances: 'max', // Use all CPU cores
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'production',
        PORT: 3003
      },
      error_file: '/home/trivia/logs/api-error.log',
      out_file: '/home/trivia/logs/api-out.log',
      log_file: '/home/trivia/logs/api-combined.log',
      time: true,
      merge_logs: true,
      max_memory_restart: '1G',
      watch: false,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 3000,
      // Environment specific settings
      env_production: {
        NODE_ENV: 'production'
      },
      env_development: {
        NODE_ENV: 'development',
        watch: true,
        ignore_watch: ['node_modules', 'logs', '.git', '*.log']
      }
    },
    {
      name: 'trivia-marketing',
      script: 'npm',
      args: 'start',
      cwd: '/home/trivia/trivia-engine/marketing',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      error_file: '/home/trivia/logs/marketing-error.log',
      out_file: '/home/trivia/logs/marketing-out.log',
      log_file: '/home/trivia/logs/marketing-combined.log',
      time: true,
      max_memory_restart: '1G',
      watch: false,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      kill_timeout: 5000,
      env_production: {
        NODE_ENV: 'production'
      }
    }
  ],

  // Deploy configuration
  deploy: {
    production: {
      user: 'trivia',
      host: process.env.DEPLOY_HOST,
      ref: 'origin/main',
      repo: process.env.REPO_URL,
      path: '/home/trivia/trivia-engine-pm2',
      'pre-deploy': 'git fetch --all',
      'post-deploy': 'npm install --prefix app && npm install --prefix marketing && npm run build --prefix marketing && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'echo "Setting up PM2 deployment"'
    }
  }
};