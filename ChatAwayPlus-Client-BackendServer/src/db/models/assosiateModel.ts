// models/associateModels.ts
import User from './user.model';
import Location from './location.model';
import CallLog from './call-log.model';
import Notification from './notification.model';

export const associateModels = () => {
  // Note: User.hasMany(Location) is already defined in user.model.ts
  // Only define Location.belongsTo here to avoid duplicate alias error
  Location.belongsTo(User, {
    foreignKey: 'userId',
    as: 'user',
  });

  // CallLog associations
  User.hasMany(CallLog, {
    foreignKey: 'callerId',
    as: 'outgoingCalls',
  });

  User.hasMany(CallLog, {
    foreignKey: 'calleeId',
    as: 'incomingCalls',
  });

  CallLog.belongsTo(User, {
    foreignKey: 'callerId',
    as: 'caller',
  });

  CallLog.belongsTo(User, {
    foreignKey: 'calleeId',
    as: 'callee',
  });

  CallLog.belongsTo(User, {
    foreignKey: 'endedBy',
    as: 'ender',
  });

  // Notification associations
  User.hasMany(Notification, {
    foreignKey: 'receiverId',
    as: 'notifications',
  });

  Notification.belongsTo(User, {
    foreignKey: 'senderId',
    as: 'senderUser',
  });

  Notification.belongsTo(User, {
    foreignKey: 'receiverId',
    as: 'receiverUser',
  });
};
