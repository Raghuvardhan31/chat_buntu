import { Config } from './interfaces/config.interface';
import { development } from './environments/development';
import { production } from './environments/production';
import dotenv from 'dotenv';

dotenv.config();

class ConfigManager {
  private static instance: ConfigManager;
  private config: Config;

  private constructor() {
    const env = process.env.NODE_ENV || 'development';
    this.config = this.loadConfig(env);
  }

  public static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  private loadConfig(env: string): Config {
    switch (env) {
      case 'production':
        return production;
      case 'development':
      default:
        return development;
    }
  }

  public getConfig(): Config {
    return this.config;
  }
}

export const config = ConfigManager.getInstance().getConfig(); 