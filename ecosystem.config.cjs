const path = require('node:path')

const ROOT_CONFIG = path.resolve(__dirname, '..')

module.exports = {
  apps: [
    {
      name: 'yozora',
      cwd: path.normalize(path.resolve(ROOT_CONFIG, 'yozora')),
      script: 'npm',
      args: 'run start',
      watch: false,
      env: {
        NODE_ENV: 'development'
      }
    }
  ]
}
