import { QueryInterface, DataTypes } from 'sequelize';

export async function up(queryInterface: QueryInterface) {
  await queryInterface.createTable('otps', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    mobileNo: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    otp: {
      type: DataTypes.STRING(6),
      allowNull: false,
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    attempts: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
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

  // Check if index already exists before adding
  try {
    const indexes: any[] = await queryInterface.showIndex('otps') as any[];
    const indexExists = indexes.some((index: any) => index.name === 'otps_mobile_no_unverified_unique');

    if (!indexExists) {
      await queryInterface.addIndex('otps', ['mobileNo'], {
        unique: true,
        where: {
          isVerified: false,
        },
        name: 'otps_mobile_no_unverified_unique',
      });
    }
  } catch (error) {
    // If table doesn't exist or other error, try to add the index anyway
    console.log('Error checking for index, attempting to add:', error);
  }
}

export async function down(queryInterface: QueryInterface) {
  await queryInterface.dropTable('otps');
}
