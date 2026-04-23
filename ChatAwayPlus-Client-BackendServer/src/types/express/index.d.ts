import User from '../../db/models/user.model';

declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}

export { }; 