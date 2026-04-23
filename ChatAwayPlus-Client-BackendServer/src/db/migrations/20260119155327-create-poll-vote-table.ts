import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.createTable('poll_votes', {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },

      pollMessageId: {
        type: DataTypes.UUID,
        allowNull: false,
      },

      userId: {
        type: DataTypes.UUID,
        allowNull: false,
      },

      optionId: {
        type: DataTypes.STRING,
        allowNull: false,
      },

    });
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.dropTable('poll_votes');
  },
};