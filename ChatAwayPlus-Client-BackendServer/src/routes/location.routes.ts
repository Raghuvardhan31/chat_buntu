import { Router } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import { uploadLocationPhotos } from '../middlewares/upload.middleware';
import {
  createLocation,
  getUserLocations,
  getLocationById,
  updateLocation,
  deleteLocation,
  getRecentLocation,
  deleteLocationPhotos,
  fetchUsersWithRecentLocations
} from '../controllers/location.controller';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Create a new location with photos
router.post('/', uploadLocationPhotos.array('photos', 10), createLocation);

// Get all locations for the authenticated user
router.get('/', getUserLocations);

// Get most recent location for the authenticated user
router.get('/recent', getRecentLocation);

// Get a specific location by ID
router.get('/:id', getLocationById);

router.post('/recent-locations', fetchUsersWithRecentLocations);

// Update a location with optional photos
router.put(
  '/:id',
  uploadLocationPhotos.array('photos', 10),
  updateLocation
);

// Delete a location
router.delete('/:id', deleteLocation);

// Delete photos from a location
router.delete('/:id/photos', deleteLocationPhotos);

export default router;
