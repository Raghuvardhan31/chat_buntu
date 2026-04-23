# Database Migration Commands

## Run Call Logs Migration on Server

### Step 1: Connect to your EC2 server

```bash
ssh ec2-user@your-server-ip
```

### Step 2: Navigate to project directory

```bash
cd /home/ec2-user
```

### Step 3: Rebuild the project (to include the fix)

```bash
npm run build
```

### Step 4: Run the migration

```bash
npx sequelize-cli db:migrate
```

**OR** if you have it as an npm script:

```bash
npm run migrate
```

### Step 5: Verify migration was successful

```bash
npx sequelize-cli db:migrate:status
```

This should show `20260214000000-create-call-logs.ts` as **up/completed**.

### Step 6: Restart PM2

```bash
pm2 restart chataway1
pm2 logs chataway1
```

---

## Alternative: Run Migration Directly with MySQL

If Sequelize CLI doesn't work, you can run the SQL directly:

### Connect to MySQL

```bash
mysql -u your_username -p your_database_name
```

### Create the call_logs table

```sql
CREATE TABLE `call_logs` (
  `id` CHAR(36) NOT NULL,
  `call_id` VARCHAR(255) NOT NULL UNIQUE,
  `caller_id` CHAR(36) NOT NULL,
  `callee_id` CHAR(36) NOT NULL,
  `call_type` ENUM('voice', 'video') NOT NULL,
  `status` ENUM('initiated', 'ringing', 'accepted', 'rejected', 'missed', 'ended', 'busy', 'unavailable') NOT NULL DEFAULT 'initiated',
  `channel_name` VARCHAR(255) NOT NULL,
  `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `answered_at` DATETIME NULL,
  `ended_at` DATETIME NULL,
  `duration` INT NULL,
  `ended_by` CHAR(36) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_call_logs_caller` FOREIGN KEY (`caller_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_call_logs_callee` FOREIGN KEY (`callee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_call_logs_ender` FOREIGN KEY (`ended_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create indexes
CREATE INDEX `idx_call_logs_caller_id` ON `call_logs` (`caller_id`);
CREATE INDEX `idx_call_logs_callee_id` ON `call_logs` (`callee_id`);
CREATE UNIQUE INDEX `idx_call_logs_call_id` ON `call_logs` (`call_id`);
CREATE INDEX `idx_call_logs_status` ON `call_logs` (`status`);
CREATE INDEX `idx_call_logs_started_at` ON `call_logs` (`started_at`);
```

---

## Troubleshooting

### If migration fails:

#### 1. Check if table already exists

```bash
mysql -u your_username -p -e "SHOW TABLES LIKE 'call_logs';" your_database_name
```

#### 2. Check Sequelize migrations table

```bash
mysql -u your_username -p -e "SELECT * FROM SequelizeMeta;" your_database_name
```

#### 3. If table exists but not in SequelizeMeta, manually add it

```sql
INSERT INTO SequelizeMeta (name) VALUES ('20260214000000-create-call-logs.ts');
```

#### 4. If you need to rollback

```bash
npx sequelize-cli db:migrate:undo
```

---

## Quick Copy-Paste Commands for EC2

```bash
# Connect to server
ssh ec2-user@your-server-ip

# Navigate to project
cd /home/ec2-user

# Rebuild
npm run build

# Run migration
npx sequelize-cli db:migrate

# Restart application
pm2 restart chataway1

# Check logs
pm2 logs chataway1 --lines 50
```

---

## Environment Variables Check

Make sure your `.env` file on the server has the correct database credentials:

```bash
cat .env | grep DB_
```

Should show:

```
DB_HOST=your-db-host
DB_PORT=3306
DB_NAME=your-database-name
DB_USER=your-username
DB_PASSWORD=your-password
```
