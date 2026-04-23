import { Request, Response } from 'express';
import { RequestHandler } from 'express';
import multer from 'multer';

interface LocationUpdateRequest extends Request {
  files?: {
    photos?: Express.Multer.File[];
  };
}

interface LocationUpdateData {
  name?: string;
  description?: string;
  photos?: string[];
}
import * as locationService from '../services/location.service';

export const createLocation = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    // Handle uploaded photos
    const photos = (req.files as Express.Multer.File[])?.map(file => {
      // NEW: Use relative URL that goes through our image serving endpoint
      // Format: /api/images/stream/locations/{userId}/{filename}
      const s3Key = (file as any).key || (file as any).location.split('.amazonaws.com/')[1];
      return `/api/images/stream/${s3Key}`;
    }) || [];

    const location = await locationService.createLocation({
      userId,
      name: req.body.name,
      description: req.body.description,
      photos,
    });

    res.status(201).json({
      success: true,
      data: location,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const getUserLocations = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const locations = await locationService.getUserLocations(userId);
    res.status(200).json({
      success: true,
      data: locations,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const getLocationById = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const location = await locationService.getLocationById(req.params.id);
    if (!location) {
      return res.status(404).json({
        success: false,
        error: 'Location not found',
      });
    }

    // Check if the location belongs to the user
    // if (location.userId !== userId) {
    //   return res.status(403).json({
    //     success: false,
    //     error: 'Forbidden',
    //   });
    // }

    res.status(200).json({
      success: true,
      data: location,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const updateLocation: RequestHandler = async (req: Request, res: Response) => {
  const locationUpdateRequest = req as LocationUpdateRequest;
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    // Extract uploaded photos from request
    const photos = (req as any).files as Express.Multer.File[];

    // Fetch the latest location from the DB
    const latestLocation = await locationService.getLocationById(req.params.id);
    if (!latestLocation) {
      return res.status(404).json({ success: false, error: 'Location not found' });
    }

    // Prepare update data
    const updateData: LocationUpdateData = {};

    // Only update name/description if provided
    if (req.body.name !== undefined) updateData.name = req.body.name;
    if (req.body.description !== undefined) updateData.description = req.body.description;

    // --- PHOTO HANDLING: Always merge old and new photos ---
    const currentPhotos = Array.isArray(latestLocation.photos) ? latestLocation.photos : [];
    let newPhotoPaths: string[] = [];
    if (photos && photos.length > 0) {
      newPhotoPaths = photos.map((photo: Express.Multer.File) => {
        // NEW: Use relative URL that goes through our image serving endpoint
        // Format: /api/images/stream/locations/{userId}/{filename}
        const s3Key = (photo as any).key || (photo as any).location.split('.amazonaws.com/')[1];
        return `/api/images/stream/${s3Key}`;
      });
    }
    // Merge old and new, remove duplicates
    const allPhotos = Array.from(new Set([...currentPhotos, ...newPhotoPaths]));
    updateData.photos = allPhotos;

    // Update location
    const location = await locationService.updateLocation(
      req.params.id,
      userId,
      updateData
    );

    if (!location) {
      return res.status(404).json({
        success: false,
        error: 'Location not found',
      });
    }

    res.status(200).json({
      success: true,
      data: location,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const getRecentLocation = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const location = await locationService.getRecentLocation(userId);

    res.status(200).json({
      success: true,
      data: location,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const deleteLocationPhotos = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    const locationId = req.params.id;
    const photosToDelete: string[] = req.body.photosToDelete;

    if (!userId) {
      return res.status(401).json({ success: false, error: 'Unauthorized' });
    }
    if (!Array.isArray(photosToDelete) || photosToDelete.length === 0) {
      return res.status(400).json({ success: false, error: 'No photos specified for deletion' });
    }

    const updatedLocation = await locationService.deleteLocationPhotos(locationId, userId, photosToDelete);

    if (!updatedLocation) {
      return res.status(404).json({ success: false, error: 'Location not found or not authorized' });
    }

    res.status(200).json({ success: true, data: updatedLocation });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};


export const deleteLocation = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const deleted = await locationService.deleteLocation(req.params.id, userId);
    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Location not found',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Location deleted successfully',
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const fetchUsersWithRecentLocations = async (req: Request, res: Response) => {
  try {
    const phoneNumbers: string[] = req.body.phoneNumbers;

    if (!Array.isArray(phoneNumbers)) {
      return res.status(400).json({ error: 'Invalid input. Expected an array of phone numbers.' });
    }

    const usersWithLocations = await locationService.getUsersRecentLocations(phoneNumbers);

    return res.status(200).json({ data: usersWithLocations });
  } catch (error) {
    console.error('Error fetching recent locations:', error);
    return res.status(500).json({ error: 'Failed to fetch recent locations' });
  }
};
