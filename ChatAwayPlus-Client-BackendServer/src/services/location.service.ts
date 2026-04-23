import { Op } from 'sequelize';

import Location from '../db/models/location.model';
import User from '../db/models/user.model';
import sequelize from '../db/config/database';

interface CreateLocationDto {
  userId: string;
  name: string;
  description?: string;
  photos?: string[];
}

export const createLocation = async (data: CreateLocationDto): Promise<Location> => {
  const locationData = {
    userId: data.userId,
    name: data.name,
    description: data.description,
    photos: data.photos,
  };

  try {
    const location = await Location.create(locationData);
    return location;
  } catch (error) {
    throw new Error(`Error creating location: ${error}`);
  }
};

export const getUserLocations = async (userId: string): Promise<Location[]> => {
  try {
    const locations = await Location.findAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
    });
    return locations;
  } catch (error) {
    throw new Error(`Error fetching user locations: ${error}`);
  }
};

export const getLocationById = async (id: string): Promise<Location | null> => {
  try {
    const location = await Location.findByPk(id);
    return location;
  } catch (error) {
    throw new Error(`Error fetching location: ${error}`);
  }
};

export const updateLocation = async (
  id: string,
  userId: string,
  data: Partial<CreateLocationDto>
): Promise<Location | null> => {
  try {
    // console.log('Updating location with data:', { id, userId, data });

    const transaction = await sequelize.transaction();

    try {
      // 🔧 Disable defaultScope to get full Sequelize instance
      const location = await Location.unscoped().findOne({
        where: { id, userId },
        transaction,
        lock: transaction.LOCK.UPDATE,
        raw: false
      });

      if (!location) {
        console.log('Location not found or not owned by user');
        await transaction.rollback();
        return null;
      }

      let existingPhotos: string[] = [];
      if (typeof location.photos === 'string') {
        try {
          existingPhotos = JSON.parse(location.photos) || [];
        } catch (error) {
          console.error('Error parsing location.photos:', error);
        }
      } else if (Array.isArray(location.photos)) {
        existingPhotos = location.photos;
      }

      // const existingPhotos: string[] = location.photos ?? [];
      const incomingPhotos: string[] = Array.isArray(data.photos) ? data.photos : [];
      const mergedPhotos = Array.from(new Set([...existingPhotos, ...incomingPhotos]));

      const updatePayload = {
        ...data,
        photos: mergedPhotos.length > 0 ? mergedPhotos : existingPhotos
      };

      await location.update(updatePayload, { transaction });

      await location.reload({ transaction });  // ✅ works now that we disabled defaultScope

      await transaction.commit();

      const updatedLocation = await Location.findByPk(id, { raw: true }); // return plain object

      return updatedLocation as Location;
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  } catch (error) {
    throw new Error(`Error updating location: ${error}`);
  }
};


export const getRecentLocation = async (userId: string): Promise<Location | null> => {
  try {
    const location = await Location.findOne({
      where: { userId },
      order: [['createdAt', 'DESC']]
    });
    return location;
  } catch (error) {
    throw new Error(`Error fetching recent location: ${error}`);
  }
};

export const deleteLocationPhotos = async (id: string, userId: string, photosToDelete?: string[]): Promise<Location | null> => {
  try {
    const transaction = await sequelize.transaction();
    try {
      const location = await Location.unscoped().findOne({
        where: { id, userId },
        transaction,
        lock: transaction.LOCK.UPDATE,
        raw: false,
      });
      if (!location) {
        await transaction.rollback();
        return null;
      }

      let existingPhotos: string[] = [];

      // Access photos from dataValues since location.photos might be undefined
      const photosData = location.dataValues.photos || location.photos;

      if (photosData) {
        if (Array.isArray(photosData)) {
          existingPhotos = photosData;
        } else if (typeof photosData === 'string') {
          // Parse the JSON string
          try {
            existingPhotos = JSON.parse(photosData);
          } catch (err) {
            console.error("Failed to parse existing photos string:", err);
            existingPhotos = [];
          }
        } else {
          console.error("Unexpected photos data type:", typeof photosData, photosData);
          existingPhotos = [];
        }
      } else {
        existingPhotos = [];
      }

      // Filter out the photos to delete
      const filteredPhotos = existingPhotos.filter(photo => !photosToDelete?.includes(photo));
      console.log('Photos to delete:', photosToDelete);
      console.log('Existing photos:', existingPhotos);
      console.log('Filtered photos:', filteredPhotos);

      if (filteredPhotos.length !== existingPhotos.length) {
        await location.update({ photos: filteredPhotos }, { transaction });
      }
      await transaction.commit();
      // Re-fetch updated location as plain object if needed
      const updated = await Location.findByPk(id, { raw: true });
      return updated as Location;
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  } catch (error) {
    throw new Error(`Error deleting photos: ${error}`);
  }
};

export const deleteLocation = async (id: string, userId: string): Promise<boolean> => {
  try {
    const deleted = await Location.destroy({
      where: { id, userId },
    });
    return deleted > 0;
  } catch (error) {
    throw new Error(`Error deleting location: ${error}`);
  }
};

export const getUsersRecentLocations = async (phoneNumbers: string[]) => {
  if (!phoneNumbers || phoneNumbers.length === 0) {
    throw new Error('Phone number list is empty');
  }

  // Find users by mobile numbers
  const users = await User.findAll({
    where: {
      mobileNo: {
        [Op.in]: phoneNumbers
      }
    },
    attributes: ['id', 'mobileNo', 'firstName', 'lastName'],
    raw: true
  });

  const userIds = users.map(user => user.id);

  if (userIds.length === 0) {
    return [];
  }

  // Fetch most recent location per user using subquery
  const recentLocations = await Location.findAll({
    where: {
      userId: {
        [Op.in]: userIds
      }
    },
    attributes: [
      'id',
      'userId',
      'name',
      'description',
      'photos',
      'createdAt',
      'updatedAt'
    ],
    order: [['createdAt', 'DESC']],
    raw: true
  });

  // Group by userId and pick the most recent
  const latestLocationPerUser: Record<string, any> = {};
  for (const loc of recentLocations) {
    if (!latestLocationPerUser[loc.userId]) {
      latestLocationPerUser[loc.userId] = loc;
    }
  }

  // Combine user and their recent location
  const result = users.map(user => ({
    user,
    recentLocation: latestLocationPerUser[user.id] || null
  }));

  return result;
};
