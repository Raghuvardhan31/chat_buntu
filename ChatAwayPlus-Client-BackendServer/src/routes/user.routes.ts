import { Router } from 'express';

import {
    createUser, getAllUsers, getUserById, updateProfile as profileUpdate, checkContactList,
    userProfile, deleteUserProfilePic, storeFcmToken, deleteUser, refreshUserDetails, getUpdatedContactsSince
} from '../controllers/user.controller';
import { authMiddleware } from '../middlewares/auth.middleware';
import { uploadProfile } from '../middlewares/upload.middleware';

const router = Router();

// Create a new user
router.post('/', (req, res) => createUser(req, res));

// Get all users
router.get('/', (req, res) => getAllUsers(req, res));

// Get user by ID
router.get('/profile/:id', (req, res) => getUserById(req, res));

router.put('/profile', authMiddleware, uploadProfile, profileUpdate);

router.get('/my-profile', authMiddleware, userProfile);

router.post('/check-contacts', authMiddleware, checkContactList);

router.post('/refresh-users', authMiddleware, refreshUserDetails);

// Delta sync endpoint - get contacts updated since timestamp
router.get('/contacts/updated-since', authMiddleware, getUpdatedContactsSince);

router.delete('/profile-pic', authMiddleware, deleteUserProfilePic);

router.post('/store-fcm-token', authMiddleware, storeFcmToken);

router.post('/delete-user', authMiddleware, deleteUser);

export default router;
