import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

import User from '../db/models/user.model';

export const authMiddleware = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    // console.log({ token })
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key') as { userId: number };

    const user = await User.findByPk(decoded.userId);

    if (!user) {
      return res.
        status(401).json({ message: 'User not found!' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid token' });
  }
};
