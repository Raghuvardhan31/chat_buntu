import { QueryInterface } from 'sequelize';
import { v4 as uuidv4 } from 'uuid';
import bcrypt from 'bcrypt';

export async function up(queryInterface: QueryInterface) {
  const hashedPassword = await bcrypt.hash('password123', 10);

  return queryInterface.bulkInsert('users', [
    {
      id: uuidv4(),
      email: 'john.doe@example.com',
      password: hashedPassword,
      firstName: 'John',
      lastName: 'Doe',
      mobileNo: '9876543210',
      isVerified: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: uuidv4(),
      email: 'jane.smith@example.com',
      password: hashedPassword,
      firstName: 'Jane',
      lastName: 'Smith',
      mobileNo: '9876543211',
      isVerified: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    // Default test users with mobile numbers for OTP testing
    {
      id: uuidv4(),
      mobileNo: '9999999991',
      firstName: 'Test',
      lastName: 'User1',
      isVerified: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: uuidv4(),
      mobileNo: '9999999992',
      firstName: 'Test',
      lastName: 'User2',
      isVerified: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ]);
}

export async function down(queryInterface: QueryInterface) {
  return queryInterface.bulkDelete('users', {});
} 