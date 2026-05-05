import { Config } from '../interfaces/config.interface';

export const production: Config = {
  env: 'production',
  port: parseInt(process.env.PORT || '3200'),
  database: {
    host: process.env.DB_HOST || '192.168.1.17',
    port: parseInt(process.env.DB_PORT || '3306'),
    username: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    name: process.env.DB_NAME || 'userdb',
  },
  smsKey: process.env.SMS_KEY || '',
  jwt: {
    secret: process.env.JWT_SECRET || 'your-strong-production-secret',
    expiresIn: process.env.JWT_EXPIRES_IN || '180d',
  },
};
