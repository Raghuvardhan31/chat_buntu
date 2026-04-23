import dotenv from 'dotenv';

import { Config } from '../interfaces/config.interface';

dotenv.config();

export const development: Config = {
  env: 'development',
  port: 3200,
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    username: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    name: process.env.DB_NAME || 'test',
  },
  smsKey: process.env.SMS_KEY || '',
  jwt: {
    secret: process.env.JWT_SECRET || 'your-secret-key',
    expiresIn: '180d',
  },
};
