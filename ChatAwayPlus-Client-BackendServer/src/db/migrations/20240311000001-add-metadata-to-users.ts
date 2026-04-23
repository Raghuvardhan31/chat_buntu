import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  up: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('Users');

    if (!tableDescription.metadata) {
      await queryInterface.addColumn('Users', 'metadata', {
        type: DataTypes.TEXT,
        defaultValue: null,
        allowNull: true
      });
    }
  },

  down: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('Users');

    if (tableDescription.metadata) {
      await queryInterface.removeColumn('Users', 'metadata');
    }
  }
};
