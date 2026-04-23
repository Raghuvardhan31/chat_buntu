import { Sequelize } from 'sequelize-typescript';

import User from '../db/models/user.model';
import { config } from './index';

const sequelize = new Sequelize({
  dialect: 'mysql',
  host: config.database.host,
  port: config.database.port,
  username: config.database.username,
  password: config.database.password,
  database: config.database.name,
  logging: false, // Disable SQL query logging
  models: [User as any], // Type assertion to resolve compatibility issue
  define: {
    charset: 'utf8mb4',
    collate: 'utf8mb4_unicode_ci',
  },
});

export default sequelize;
