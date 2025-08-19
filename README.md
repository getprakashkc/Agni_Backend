# Agni Backend - Financial Trading System with PostgreSQL

A comprehensive PostgreSQL database setup with Docker for a financial trading system, optimized for Coolify deployment on Ubuntu server.

## 🚀 Features

- **Automatic Setup**: PostgreSQL automatically installs Python extensions and packages on startup
- **Persistent Data**: Data is stored in Docker volumes that survive container restarts
- **Python Integration**: Built-in `plpython3u` extension with `requests` package
- **Financial Schema**: Complete trading system with brokers, instruments, and OHLC data
- **Health Checks**: Built-in health monitoring for database availability
- **Coolify Ready**: Optimized for Coolify deployment

## 📋 Prerequisites

- Docker and Docker Compose installed on Ubuntu server
- At least 2GB of available RAM
- 10GB of available disk space

## 🛠️ Quick Start

### 1. Deploy to Coolify

1. **Push to Git** repository
2. **Add to Coolify** as a new application
3. **Select Docker Compose** as deployment method
4. **Deploy** - Coolify will handle the rest

### 2. Manual Deployment (if needed)

```bash
# Clone and deploy
git clone <your-repo>
cd Agni_Backend
docker-compose up -d

# Check status
docker-compose ps
```

## 🗄️ Database Details

- **Host**: localhost (or server IP)
- **Port**: 5432
- **Database**: agni_db
- **Username**: agni_user
- **Password**: agni_password
- **Extensions**: plpython3u
- **Python Packages**: requests

## 📊 Database Schema

### Core Tables
- **brokers** - Broker information (Upstox, Zerodha, etc.)
- **exchanges** - Exchange details (NSE, BSE, MCX)
- **instrument_types** - Instrument categories (EQ, FUT, CE, PE, etc.)
- **instruments** - Main instrument master data
- **ohlc_daily** - Daily OHLC price data
- **ohlc_intraday** - Intraday OHLC data (5-minute candles)
- **ohlc_refresh_history** - OHLC data refresh tracking
- **master_data_refresh_history** - Master data refresh tracking

### Key Features
- **Multi-broker support** (Upstox, Zerodha)
- **Multi-exchange support** (NSE, BSE, MCX)
- **Comprehensive instrument data** with derivatives support
- **OHLC data storage** for technical analysis
- **Automatic timestamp updates** via triggers
- **Performance indexes** for fast queries
- **Data validation constraints** for data integrity

## 📁 Project Structure

```
Agni_Backend/
├── docker-compose.yml              # Main Docker Compose file
├── Dockerfile.postgres             # Custom PostgreSQL image
├── init-scripts/                   # SQL scripts that run on first startup
│   └── 01-init.sql                # Complete trading system schema
├── database_schema.sql             # Original schema file (reference)
└── postgres-data/                  # Persistent data storage (created automatically)
```

## 🐍 Python Integration

The database automatically includes:

- **plpython3u** extension for Python functions
- **requests** package for HTTP operations
- Python virtual environment at `/opt/venv`

### Example Python Function

```sql
CREATE OR REPLACE FUNCTION test_http()
RETURNS text
LANGUAGE plpython3u
AS $$
import requests
response = requests.get('https://httpbin.org/get')
return f"Status: {response.status_code}"
$$;
```

## 🔄 Automatic Script Execution

### On First Startup
1. PostgreSQL container starts
2. `init-scripts/01-init.sql` runs automatically
3. Creates complete trading system schema
4. Inserts initial master data (brokers, exchanges, instrument types)
5. Sets up triggers and functions

### On Restart/Deployment
1. Container restarts with existing data
2. Health checks ensure database is ready
3. All extensions, packages, and schema are preserved

## 📊 Monitoring

### Health Check
```bash
# Check if database is healthy
docker-compose ps

# View logs
docker-compose logs postgres
```

### Database Verification
```sql
-- Check tables created
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check initial data
SELECT * FROM brokers;
SELECT * FROM exchanges;
SELECT * FROM instrument_types;
```

## 🚨 Troubleshooting

### Common Issues

1. **Container Won't Start**
   ```bash
   # Check Docker logs
   docker-compose logs postgres
   
   # Check available resources
   docker system df
   ```

2. **Port Already in Use**
   ```bash
   # Check what's using port 5432
   sudo netstat -tlnp | grep :5432
   
   # Stop existing PostgreSQL service
   sudo systemctl stop postgresql
   ```

### Reset Everything
```bash
# Remove containers and volumes
docker-compose down -v

# Start fresh
docker-compose up -d
```

## 🔒 Security Notes

- Default credentials are for development only
- Change passwords in production
- Consider using environment variables for credentials
- Database is accessible from server only

## 🚀 Production Considerations

For production deployment:

1. Change default passwords
2. Use environment variables for credentials
3. Enable SSL connections
4. Configure backup schedules
5. Monitor resource usage
6. Consider partitioning for large OHLC datasets

## 📝 Environment Variables

You can override default values by setting environment variables:

```bash
export POSTGRES_DB=your_db_name
export POSTGRES_USER=your_username
export POSTGRES_PASSWORD=your_secure_password
```

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section
2. Review Docker logs: `docker-compose logs postgres`
3. Verify system requirements
4. Check Coolify logs
5. Verify schema creation: `docker-compose exec postgres psql -U agni_user -d agni_db -c "\dt"`

---

**Happy trading! 📈🎉**
