import { QueryInterface, DataTypes } from 'sequelize';

export default {
  up: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('statuses');
    if (!tableDescription.deletedAt) {
      await queryInterface.addColumn('statuses', 'deletedAt', {
        type: DataTypes.DATE,
        allowNull: true,
        defaultValue: null,
      });
    }
  },

  down: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('statuses');
    if (tableDescription.deletedAt) {
      await queryInterface.removeColumn('statuses', 'deletedAt');
    }
  },
};
