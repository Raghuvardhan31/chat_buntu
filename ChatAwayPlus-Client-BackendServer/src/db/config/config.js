require('ts-node/register');
require('dotenv').config();

// Import the TypeScript configuration
const { config } = require('../../config');

module.exports = {
  development: {
    username: config.database.username,
    password: config.database.password,
    database: config.database.name,
    host: config.database.host,
    port: config.database.port,
    dialect: 'mysql',
    logging: config.env === 'development',
    define: {
      timestamps: true,
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci'
    }
  },
  test: {
    username: config.database.username,
    password: config.database.password,
    database: config.database.name + '_test',
    host: config.database.host,
    port: config.database.port,
    dialect: 'mysql',
    logging: false,
    define: {
      timestamps: true,
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci'
    }
  },
  production: {
    username: config.database.username,
    password: config.database.password,
    database: config.database.name,
    host: config.database.host,
    port: config.database.port,
    dialect: 'mysql',
    logging: false,
    define: {
      timestamps: true,
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci'
    }
  }
};
