import sequelize from './config/database';
import User from './models/user.model';
// Import other models here

async function syncDatabase() {
  try {
    // Force true will drop tables if they exist
    // Set to false in production!
    await sequelize.sync({ alter: true });
    console.log('Database synchronized successfully.');
  } catch (error) {
    console.error('Error synchronizing database:', error);
  } finally {
    process.exit();
  }
}

syncDatabase(); 