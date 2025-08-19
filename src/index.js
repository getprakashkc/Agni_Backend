const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const dbConnection = require('./database/connection');
const DatabaseMigrator = require('./database/migrate');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const dbHealth = await dbConnection.healthCheck();
    const overallHealth = dbHealth.status === 'healthy';
    
    res.status(overallHealth ? 200 : 503).json({
      status: overallHealth ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      database: dbHealth,
      uptime: process.uptime(),
      memory: process.memoryUsage()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Database status endpoint
app.get('/db/status', async (req, res) => {
  try {
    const status = await dbConnection.healthCheck();
    res.json(status);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Manual migration trigger endpoint
app.post('/db/migrate', async (req, res) => {
  try {
    const migrator = new DatabaseMigrator();
    await migrator.migrate();
    res.json({ message: 'Migrations completed successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🔄 SIGTERM received, shutting down gracefully...');
  await dbConnection.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🔄 SIGINT received, shutting down gracefully...');
  await dbConnection.close();
  process.exit(0);
});

// Start the application
async function startApp() {
  try {
    // Connect to database
    await dbConnection.connect();
    
    // Run migrations on startup
    console.log('🔄 Running database migrations...');
    const migrator = new DatabaseMigrator();
    await migrator.migrate();
    
    // Start the server
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📊 Health check available at http://localhost:${PORT}/health`);
      console.log(`🗄️  Database status at http://localhost:${PORT}/db/status`);
    });
    
  } catch (error) {
    console.error('❌ Failed to start application:', error);
    process.exit(1);
  }
}

startApp();
