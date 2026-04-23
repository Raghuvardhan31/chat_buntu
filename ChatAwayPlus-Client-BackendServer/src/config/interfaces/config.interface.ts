export interface Config {
  env: string;
  port: number;
  database: {
    host: string;
    port: number;
    username: string;
    password: string;
    name: string;
  };
  smsKey: string,
  jwt?: {
    secret: string;
    expiresIn: string;
  };
  aws?: {
    accessKeyId: string;
    secretAccessKey: string;
    region: string;
    s3BucketName: string;
  };
}
