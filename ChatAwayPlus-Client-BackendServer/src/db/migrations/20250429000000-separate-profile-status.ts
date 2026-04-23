import { QueryInterface, DataTypes } from 'sequelize';

export default {
  up: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('users');

    // Add new columns only if they don't exist
    if (!tableDescription.profile_pic) {
      await queryInterface.addColumn('users', 'profile_pic', {
        type: DataTypes.STRING,
        allowNull: true,
      });
    }

    if (!tableDescription.status) {
      await queryInterface.addColumn('users', 'status', {
        type: DataTypes.STRING,
        allowNull: true,
        defaultValue: 'Hey there! I am using WhatsApp',
      });

      // Move data from metadata to new columns only if status column was just created
      await queryInterface.sequelize.query(`
        UPDATE users
        SET
          profile_pic = CAST(JSON_EXTRACT(metadata, '$.profile_pic') AS CHAR),
          status = COALESCE(CAST(JSON_EXTRACT(metadata, '$.status') AS CHAR), 'Hey there! I am using WhatsApp')
        WHERE metadata IS NOT NULL;
      `);
    }
  },

  down: async (queryInterface: QueryInterface) => {
    const tableDescription = await queryInterface.describeTable('users');

    // Revert changes
    if (tableDescription.profile_pic) {
      await queryInterface.removeColumn('users', 'profile_pic');
    }

    if (tableDescription.status) {
      await queryInterface.removeColumn('users', 'status');
    }
  },
};
