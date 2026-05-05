import { Router } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import {
  createGroup,
  getMyGroups,
  getGroupDetails,
  updateGroup,
  addMembers,
  removeMember,
  deleteGroup,
  getGroupMessages,
  sendGroupMessage,
  updateMemberRole,
} from '../controllers/group.controller';

const router = Router();

// All group routes require authentication
router.use(authMiddleware);

// ─── Group CRUD ───────────────────────────────────────────────────────────────
router.post('/', createGroup);                              // POST   /api/groups
router.get('/my', getMyGroups);                             // GET    /api/groups/my
router.get('/:groupId', getGroupDetails);                   // GET    /api/groups/:groupId
router.put('/:groupId', updateGroup);                       // PUT    /api/groups/:groupId
router.delete('/:groupId', deleteGroup);                    // DELETE /api/groups/:groupId

// ─── Member Management ────────────────────────────────────────────────────────
router.post('/:groupId/members', addMembers);               // POST   /api/groups/:groupId/members
router.delete('/:groupId/members/:targetUserId', removeMember); // DELETE /api/groups/:groupId/members/:targetUserId
router.patch('/:groupId/members/:targetUserId/role', updateMemberRole); // PATCH /api/groups/:groupId/members/:targetUserId/role

// ─── Messages ─────────────────────────────────────────────────────────────────
router.get('/:groupId/messages', getGroupMessages);         // GET    /api/groups/:groupId/messages
router.post('/:groupId/messages', sendGroupMessage);        // POST   /api/groups/:groupId/messages (REST fallback)

export default router;
