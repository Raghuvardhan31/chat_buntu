import type { QueryInterface } from 'sequelize';

export interface Migration {
  up: (args: { context: QueryInterface }) => Promise<void>;
  down: (args: { context: QueryInterface }) => Promise<void>;
} 