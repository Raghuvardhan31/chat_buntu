import { QueryInterface, DataTypes } from 'sequelize';

export default {
  up: async (queryInterface: QueryInterface) => {
    // Create status table
    await queryInterface.createTable('statuses', {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        allowNull: false,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      content: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      likesCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false,
      },
    });

    // Create status_likes table for many-to-many relationship
    await queryInterface.createTable('status_likes', {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        allowNull: false,
        primaryKey: true,
      },
      statusId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'statuses',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false,
      },
    });

    // Add unique constraint to prevent duplicate likes
    try {
      const indexes: any[] = await queryInterface.showIndex('status_likes') as any[];
      const constraintExists = indexes.some((index: any) => index.Key_name === 'unique_status_like');

      if (!constraintExists) {
        await queryInterface.addConstraint('status_likes', {
          fields: ['statusId', 'userId'],
          type: 'unique',
          name: 'unique_status_like',
        });
      }
    } catch (error) {
      // Constraint might already exist, skip
      console.log('Constraint may already exist, skipping');
    }
  },

  down: async (queryInterface: QueryInterface) => {
    await queryInterface.dropTable('status_likes');
    await queryInterface.dropTable('statuses');
  },
};
