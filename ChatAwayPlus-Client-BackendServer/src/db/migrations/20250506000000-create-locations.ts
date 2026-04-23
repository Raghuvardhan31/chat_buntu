import { QueryInterface, DataTypes } from 'sequelize';

export async function up(queryInterface: QueryInterface) {
  await queryInterface.createTable('locations', {
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
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    photos: {
      type: DataTypes.JSON,  // Will store array of photo URLs
      allowNull: true,
      defaultValue: [],
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

  // Add index for faster lookups by userId
  try {
    const indexes: any[] = await queryInterface.showIndex('locations') as any[];
    const indexExists = indexes.some((index: any) => index.Key_name === 'locations_user_id');

    if (!indexExists) {
      await queryInterface.addIndex('locations', ['userId']);
    }
  } catch (error) {
    // Index might already exist, skip
    console.log('Index may already exist, skipping');
  }
}

export async function down(queryInterface: QueryInterface) {
  await queryInterface.dropTable('locations');
}
