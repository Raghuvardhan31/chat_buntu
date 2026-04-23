import { QueryInterface } from 'sequelize';

export default {
  up: async (queryInterface: QueryInterface): Promise<void> => {
    const tableDescription = await queryInterface.describeTable('users');
    if (tableDescription.status) {
      await queryInterface.removeColumn('users', 'status');
    }
  },

  down: async (queryInterface: QueryInterface): Promise<void> => {
    const tableDescription = await queryInterface.describeTable('users');
    if (!tableDescription.status) {
      await queryInterface.addColumn('users', 'status', {
        type: 'STRING',
        allowNull: true,
        defaultValue: 'Hey there! I am using WhatsApp'
      });
    }
  }
};
