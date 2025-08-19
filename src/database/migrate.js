const dbConnection = require('./connection');
const fs = require('fs').promises;
const path = require('path');

class DatabaseMigrator {
  constructor() {
    this.migrationsTable = 'schema_migrations';
    this.migrationsPath = path.join(__dirname, 'migrations');
  }

  async initialize() {
    try {
      await dbConnection.connect();
      await this.createMigrationsTable();
      console.log('✅ Migration system initialized');
    } catch (error) {
      console.error('❌ Failed to initialize migration system:', error);
      throw error;
    }
  }

  async createMigrationsTable() {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS ${this.migrationsTable} (
        id SERIAL PRIMARY KEY,
        version VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        checksum VARCHAR(64),
        execution_time INTEGER
      );
    `;
    
    await dbConnection.query(createTableQuery);
  }

  async getExecutedMigrations() {
    const query = `SELECT version FROM ${this.migrationsTable} ORDER BY id`;
    const result = await dbConnection.query(query);
    return result.rows.map(row => row.version);
  }

  async getMigrationFiles() {
    try {
      const files = await fs.readdir(this.migrationsPath);
      return files
        .filter(file => file.endsWith('.sql'))
        .sort();
    } catch (error) {
      console.log('No migrations directory found, creating one...');
      await fs.mkdir(this.migrationsPath, { recursive: true });
      return [];
    }
  }

  async runMigration(filePath, version, name) {
    const startTime = Date.now();
    
    try {
      const sqlContent = await fs.readFile(filePath, 'utf8');
      const statements = sqlContent
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0);

      // Execute each statement
      for (const statement of statements) {
        if (statement.trim()) {
          await dbConnection.query(statement);
        }
      }

      const executionTime = Date.now() - startTime;
      
      // Record successful migration
      const insertQuery = `
        INSERT INTO ${this.migrationsTable} (version, name, execution_time)
        VALUES ($1, $2, $3)
      `;
      
      await dbConnection.query(insertQuery, [version, name, executionTime]);
      
      console.log(`✅ Migration ${version} (${name}) executed successfully in ${executionTime}ms`);
      
    } catch (error) {
      console.error(`❌ Migration ${version} (${name}) failed:`, error);
      throw error;
    }
  }

  async migrate() {
    try {
      await this.initialize();
      
      const executedMigrations = await this.getExecutedMigrations();
      const migrationFiles = await this.getMigrationFiles();
      
      console.log(`📊 Found ${migrationFiles.length} migration files`);
      console.log(`📊 Already executed: ${executedMigrations.length}`);
      
      let executedCount = 0;
      
      for (const file of migrationFiles) {
        const version = file.replace('.sql', '');
        const name = file.replace('.sql', '').replace(/_/g, ' ');
        
        if (!executedMigrations.includes(version)) {
          console.log(`🔄 Running migration: ${version} (${name})`);
          const filePath = path.join(this.migrationsPath, file);
          await this.runMigration(filePath, version, name);
          executedCount++;
        } else {
          console.log(`⏭️  Migration ${version} already executed, skipping...`);
        }
      }
      
      if (executedCount === 0) {
        console.log('✨ Database is up to date, no new migrations to run');
      } else {
        console.log(`🎉 Successfully executed ${executedCount} new migrations`);
      }
      
    } catch (error) {
      console.error('❌ Migration failed:', error);
      throw error;
    } finally {
      await dbConnection.close();
    }
  }

  async createMigration(name) {
    const timestamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
    const fileName = `${timestamp}_${name.replace(/\s+/g, '_')}.sql`;
    const filePath = path.join(this.migrationsPath, fileName);
    
    const template = `-- Migration: ${name}
-- Created: ${new Date().toISOString()}
-- Description: Add your SQL statements here

-- Example:
-- CREATE TABLE IF NOT EXISTS example_table (
--     id SERIAL PRIMARY KEY,
--     name VARCHAR(255) NOT NULL,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- Add your migration SQL here
`;

    await fs.writeFile(filePath, template);
    console.log(`📝 Created migration file: ${fileName}`);
    return fileName;
  }
}

// CLI support
if (require.main === module) {
  const migrator = new DatabaseMigrator();
  
  const command = process.argv[2];
  const name = process.argv[3];
  
  switch (command) {
    case 'migrate':
      migrator.migrate().catch(console.error);
      break;
    case 'create':
      if (!name) {
        console.error('❌ Please provide a migration name');
        process.exit(1);
      }
      migrator.createMigration(name).catch(console.error);
      break;
    default:
      console.log('Usage:');
      console.log('  node migrate.js migrate     - Run all pending migrations');
      console.log('  node migrate.js create <name> - Create a new migration file');
      process.exit(1);
  }
}

module.exports = DatabaseMigrator;
