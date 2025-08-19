# 🚀 Agni Backend Deployment Guide

## 📋 Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Coolify Deployment](#coolify-deployment)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [File Structure](#file-structure)

## 🎯 Overview

This guide covers deploying the Agni Backend - a PostgreSQL-based financial trading system database with Python integration capabilities. The system is designed to handle multiple brokers, exchanges, instrument types, and OHLC data for Indian markets (NSE, BSE, MCX).

## ✅ Prerequisites

- **Git** - Version control
- **Docker** - Containerization
- **Docker Compose** - Multi-container orchestration
- **Coolify** - Deployment platform (Ubuntu server)
- **GitHub Repository** - Code hosting

## 🏗️ Local Development Setup

### 1. Clone Repository
```bash
git clone https://github.com/getprakashkc/Agni_Backend.git
cd Agni_Backend
```

### 2. Build and Test Locally
```bash
# Build the custom PostgreSQL image
docker compose build

# Start the database
docker compose up -d

# Check container status
docker compose ps

# View logs
docker compose logs postgres

# Connect to database
docker exec -it agni_postgres psql -U agni_user -d agni_db
```

### 3. Verify Schema Creation
```sql
-- List all tables
\dt

-- Check specific tables
SELECT * FROM brokers;
SELECT * FROM exchanges;
SELECT * FROM instrument_types;

-- Verify Python extension
SELECT * FROM system_info;
```

### 4. Stop Local Environment
```bash
docker compose down -v
```

## 🌐 Coolify Deployment

### 1. Repository Setup
- Ensure all changes are committed and pushed to GitHub
- Repository should contain:
  - `docker-compose.yaml`
  - `Dockerfile.postgres`
  - `init-scripts/01-init.sql`
  - Other project files

### 2. Coolify Configuration
1. **Create New Application**
   - **Build Pack**: Select "Docker Compose"
   - **Repository**: `getprakashkc/Agni_Backend`
   - **Branch**: `main`

2. **Environment Variables** (Optional)
   - `POSTGRES_DB`: `agni_db`
   - `POSTGRES_USER`: `agni_user`
   - `POSTGRES_PASSWORD`: `agni_password_2025`

3. **Persistent Storage**
   - **IMPORTANT**: Do NOT add any volume mounts for `init-scripts`
   - Only keep the PostgreSQL data volume (auto-created)
   - Delete any auto-created init-scripts volume mounts

### 3. Deploy
- Click "Deploy" and wait for build completion
- Monitor logs for successful initialization

## 🚨 Troubleshooting

### Problem: "PostgreSQL Database directory appears to contain a database; Skipping initialization"

**Root Cause**: Coolify is reusing an existing persistent volume, preventing init scripts from running.

**Solution**:
1. **Delete Persistent Volumes in Coolify**:
   - Go to Configuration → Persistent Storage
   - Delete ALL volumes (including PostgreSQL data volume)
   - Redeploy

2. **Manual Cleanup via SSH** (if Coolify cleanup doesn't work):
   ```bash
   # SSH into your server
   ssh agni@your-server-ip
   
   # List containers
   sudo docker ps -a
   
   # Stop and remove the container
   sudo docker stop [container-name]
   sudo docker rm [container-name]
   
   # List volumes
   sudo docker volume ls
   
   # Remove the problematic volume (be careful not to delete other volumes)
   sudo docker volume rm [volume-name]
   
   # Redeploy from Coolify
   ```

### Problem: "ignoring /docker-entrypoint-initdb.d/*"

**Root Cause**: Init scripts directory is not accessible or empty.

**Solution**:
1. **Check Dockerfile**: Ensure `COPY init-scripts/ /docker-entrypoint-initdb.d/` is present
2. **Remove Volume Mounts**: Delete any init-scripts volume mounts in Coolify
3. **Verify File Structure**: Ensure `init-scripts/01-init.sql` exists in repository

### Problem: Schema Tables Not Created

**Root Cause**: Init scripts are not running due to volume conflicts.

**Solution**:
1. **Force Fresh Database**: Remove all persistent volumes
2. **Redeploy**: Let PostgreSQL create a completely new database
3. **Monitor Logs**: Look for init script execution messages

## 🏛️ Architecture

### Database Schema
- **Master Data Tables**: brokers, exchanges, instrument_types
- **Core Tables**: instruments, ohlc_daily, ohlc_intraday
- **History Tables**: ohlc_refresh_history, master_data_refresh_history
- **System Tables**: system_info

### Key Features
- **Python Integration**: `plpython3u` extension for custom functions
- **Automatic Timestamps**: Triggers for `last_updated` fields
- **Flexible Data Storage**: JSONB support for raw data
- **Multi-Broker Support**: Designed for multiple trading platforms

### Docker Setup
- **Base Image**: `postgres:15-alpine`
- **Custom Packages**: `postgresql-plpython3`, `python3`, `py3-pip`
- **Python Dependencies**: `requests` package
- **Init Scripts**: Automatically run on first database creation

## 📁 File Structure

```
Agni_Backend/
├── docker-compose.yaml          # Main orchestration file
├── Dockerfile.postgres          # Custom PostgreSQL image
├── init-scripts/                # Database initialization
│   └── 01-init.sql             # Complete schema and data
├── database_schema.sql          # Original schema reference
├── config.env.example           # Environment configuration example
├── package.json                 # Node.js dependencies (if needed)
├── README.md                    # Project documentation
└── DEPLOYMENT_GUIDE.md         # This file
```

## 🔑 Key Configuration Points

### Docker Compose
```yaml
services:
  postgres:
    build:
      context: .
      dockerfile: Dockerfile.postgres
    environment:
      POSTGRES_DB: agni_db
      POSTGRES_USER: agni_user
      POSTGRES_PASSWORD: agni_password_2025
    volumes:
      - postgres_data:/var/lib/postgresql/data
      # NO init-scripts volume mount here
```

### Dockerfile
```dockerfile
FROM postgres:15-alpine

# Install required packages
RUN apk update && \
    apk add --no-cache \
        postgresql-plpython3 \
        python3 \
        py3-pip

# Copy initialization scripts directly into the image
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Set environment variables
ENV PYTHONPATH=/opt/venv/lib/python3.9/site-packages
```

## 🚀 Best Practices

### 1. Volume Management
- **Never mount** `init-scripts` as a volume in Coolify
- **Let Dockerfile** handle script copying
- **Use persistent volumes** only for actual data (not scripts)

### 2. Database Initialization
- **Init scripts run once** on first database creation
- **Subsequent deployments** won't re-run scripts
- **Force fresh database** by removing volumes if needed

### 3. Coolify Configuration
- **Use Docker Compose** build pack
- **Monitor deployment logs** for any errors
- **Clean up volumes** if initialization fails

### 4. Testing
- **Test locally first** with `docker compose up -d`
- **Verify schema creation** before deploying to Coolify
- **Check logs** for any initialization issues

## 🔍 Monitoring and Maintenance

### Health Checks
- **Container Health**: `docker ps` shows container status
- **Database Health**: `pg_isready` checks database connectivity
- **Log Monitoring**: Watch for init script execution messages

### Backup and Recovery
- **Volume Backups**: Backup the `postgres_data` volume
- **Schema Backup**: Export schema with `pg_dump`
- **Recovery**: Restore from volume backup or schema export

### Updates and Maintenance
- **Schema Changes**: Modify `init-scripts/01-init.sql`
- **Dependencies**: Update `Dockerfile.postgres` for new packages
- **Redeployment**: Always test locally before Coolify deployment

## 📞 Support and Troubleshooting

### Common Issues
1. **Init scripts not running** → Check volume mounts and Dockerfile
2. **Tables not created** → Force fresh database creation
3. **Permission errors** → Verify user creation and grants
4. **Python extension errors** → Check package installation in Dockerfile

### Debug Commands
```bash
# Check container logs
docker logs [container-name]

# Verify init scripts in container
docker exec [container-name] ls -la /docker-entrypoint-initdb.d/

# Test database connection
docker exec [container-name] psql -U agni_user -d agni_db -c "\dt"

# Check volume mounts
docker inspect [container-name] | grep -A 10 "Mounts"
```

## 🎯 Success Criteria

Your deployment is successful when:
- ✅ **Container starts** without errors
- ✅ **Init scripts execute** (visible in logs)
- ✅ **All 9 tables** are created
- ✅ **Python extension** is available
- ✅ **Initial data** is populated
- ✅ **Database is accessible** on port 5432

---

**Last Updated**: August 19, 2025  
**Version**: 1.0  
**Author**: Agni Backend Team
