import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

import { config } from '../config';
import User from '../db/models/user.model';

// Extend Express Request type
declare module 'express-serve-static-core' {
  interface Request {
    user?: Pick<User, 'id' | 'email' | 'firstName' | 'lastName'>;
  }
}

// Type for JWT payload
type JwtPayload = {
  id: string;
};

export const authenticateToken = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication token required' });
  }

  try {
    if (!config.jwt?.secret) {
      throw new Error('JWT secret is not configured');
    }
    const decoded = jwt.verify(token, config.jwt.secret) as { id: string };
    
    // Get user from database
    const user = await User.findByPk(decoded.id, {
      attributes: ['id', 'email', 'firstName', 'lastName']
    });
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    req.user = user;

    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
};
