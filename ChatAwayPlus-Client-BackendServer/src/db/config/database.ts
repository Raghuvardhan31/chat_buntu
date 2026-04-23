import { Sequelize } from 'sequelize';
import { config } from '../../config';

// Sequelize instance for application use
const sequelize = new Sequelize({
  dialect: 'mysql',
  host: config.database.host,
  port: config.database.port,
  username: config.database.username,
  password: config.database.password,
  database: config.database.name,
  logging: false, // Disable SQL query logging
  define: {
    timestamps: true,
    charset: 'utf8mb4',
    collate: 'utf8mb4_unicode_ci'
  }
});

sequelize.authenticate()
  .then(() => {
    console.log('✅ Database connection established successfully.');
  })
  .catch((error) => {
    console.error('❌ Unable to connect to the database:', error);
  });

// Export sequelize instance as default (for application use)
export default sequelize;
