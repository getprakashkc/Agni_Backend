-- Initial database setup script for Agni Backend
-- This runs automatically when the database is first created

-- Debug: Log that script is running
\echo 'Starting Agni Backend database initialization...'

-- Create the plpython3u extension for Python integration
CREATE EXTENSION IF NOT EXISTS plpython3u;
\echo 'Created plpython3u extension'

-- Ensure agni_user exists (PostgreSQL creates this automatically from environment variables)
\echo 'Current user: ' || current_user;
\echo 'Available users:';
\du

-- Grant necessary permissions to the application user
GRANT USAGE ON SCHEMA public TO agni_user;
GRANT CREATE ON SCHEMA public TO agni_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO agni_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO agni_user;
\echo 'Granted permissions to agni_user'

-- Broker Instrument Master Data Schema
-- Supports multiple brokers, exchanges, and instrument types
-- Designed for Indian markets (NSE, BSE, MCX) with extensibility

-- Brokers table
CREATE TABLE IF NOT EXISTS brokers (
    id SERIAL PRIMARY KEY,
    broker_code VARCHAR(50) UNIQUE NOT NULL,
    broker_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
\echo 'Created brokers table'

-- Exchanges table
CREATE TABLE IF NOT EXISTS exchanges (
    id SERIAL PRIMARY KEY,
    exchange_code VARCHAR(20) UNIQUE NOT NULL,
    exchange_name VARCHAR(100) NOT NULL,
    country VARCHAR(50) DEFAULT 'INDIA',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
\echo 'Created exchanges table'

-- Instrument types table
CREATE TABLE IF NOT EXISTS instrument_types (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL, -- EQ, DERIVATIVES, INDEX, etc.
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
\echo 'Created instrument_types table'

-- Main instruments table
CREATE TABLE IF NOT EXISTS instruments (
    id SERIAL PRIMARY KEY,
    broker_id INTEGER REFERENCES brokers(id),
    exchange_id INTEGER REFERENCES exchanges(id),
    instrument_type_id INTEGER REFERENCES instrument_types(id),
    
    -- Core identifiers
    instrument_key VARCHAR(100) NOT NULL,
    trading_symbol VARCHAR(100) NOT NULL,
    exchange_token VARCHAR(50),
    isin VARCHAR(20),
    
    -- Basic information
    name VARCHAR(200),
    short_name VARCHAR(100),
    segment VARCHAR(50),
    
    -- Trading parameters
    lot_size INTEGER DEFAULT 1,
    tick_size DECIMAL(10,4) DEFAULT 0.01,
    freeze_quantity DECIMAL(15,2),
    minimum_lot INTEGER,
    
    -- Derivatives specific fields
    expiry BIGINT, -- Unix timestamp
    strike_price DECIMAL(15,4),
    underlying_symbol VARCHAR(100),
    underlying_key VARCHAR(100),
    underlying_type VARCHAR(50),
    weekly BOOLEAN DEFAULT false,
    
    -- Additional features
    mtf_enabled BOOLEAN DEFAULT false,
    mtf_bracket DECIMAL(10,4),
    qty_multiplier INTEGER DEFAULT 1,
    intraday_margin DECIMAL(10,4),
    intraday_leverage DECIMAL(10,4),
    security_type VARCHAR(50) DEFAULT 'NORMAL',
    
    -- Metadata
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_source VARCHAR(50), -- 'UPSTOX', 'ZERODHA', etc.
    raw_data JSONB, -- Store complete JSON response for flexibility
    
    -- Constraints
    UNIQUE(broker_id, instrument_key),
    UNIQUE(broker_id, exchange_id, trading_symbol, instrument_type_id)
);
\echo 'Created instruments table'

-- OHLC Data Tables for FNO Analysis
-- Daily OHLC data table
CREATE TABLE IF NOT EXISTS ohlc_daily (
    id SERIAL PRIMARY KEY,
    instrument_key VARCHAR(100) NOT NULL,
    trading_symbol VARCHAR(100) NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(15,4) NOT NULL,
    high_price DECIMAL(15,4) NOT NULL,
    low_price DECIMAL(15,4) NOT NULL,
    close_price DECIMAL(15,4) NOT NULL,
    volume BIGINT DEFAULT 0,
    open_interest BIGINT DEFAULT 0,
    data_source VARCHAR(50) DEFAULT 'UPSTOX',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE(instrument_key, date),
    CONSTRAINT valid_prices CHECK (
        low_price <= open_price AND low_price <= close_price AND
        high_price >= open_price AND high_price >= close_price
    )
);

-- Intraday OHLC data table (5-minute candles)
CREATE TABLE IF NOT EXISTS ohlc_intraday (
    id SERIAL PRIMARY KEY,
    instrument_key VARCHAR(100) NOT NULL,
    trading_symbol VARCHAR(100) NOT NULL,
    date DATE NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    open_price DECIMAL(15,4) NOT NULL,
    high_price DECIMAL(15,4) NOT NULL,
    low_price DECIMAL(15,4) NOT NULL,
    close_price DECIMAL(15,4) NOT NULL,
    volume BIGINT DEFAULT 0,
    open_interest BIGINT DEFAULT 0,
    data_source VARCHAR(50) DEFAULT 'UPSTOX',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE(instrument_key, timestamp),
    CONSTRAINT valid_prices CHECK (
        low_price <= open_price AND low_price <= close_price AND
        high_price >= open_price AND high_price >= close_price
    )
);

-- OHLC data refresh history
CREATE TABLE IF NOT EXISTS ohlc_refresh_history (
    id SERIAL PRIMARY KEY,
    instrument_key VARCHAR(100),
    trading_symbol VARCHAR(100),
    data_type VARCHAR(20) NOT NULL, -- 'DAILY', 'INTRADAY'
    date DATE NOT NULL,
    refresh_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED
    records_processed INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds INTEGER
);

-- Master data refresh history
CREATE TABLE IF NOT EXISTS master_data_refresh_history (
    id SERIAL PRIMARY KEY,
    broker_id INTEGER REFERENCES brokers(id),
    exchange_code VARCHAR(20),
    instrument_type_code VARCHAR(20),
    refresh_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED
    records_processed INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_deleted INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds INTEGER
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_instruments_broker ON instruments(broker_id);
CREATE INDEX IF NOT EXISTS idx_instruments_exchange ON instruments(exchange_id);
CREATE INDEX IF NOT EXISTS idx_instruments_type ON instruments(instrument_type_id);
CREATE INDEX IF NOT EXISTS idx_instruments_symbol ON instruments(trading_symbol);
CREATE INDEX IF NOT EXISTS idx_instruments_key ON instruments(instrument_key);
CREATE INDEX IF NOT EXISTS idx_instruments_underlying ON instruments(underlying_symbol);
CREATE INDEX IF NOT EXISTS idx_instruments_expiry ON instruments(expiry);

-- OHLC data indexes
CREATE INDEX IF NOT EXISTS idx_ohlc_daily_instrument ON ohlc_daily(instrument_key);
CREATE INDEX IF NOT EXISTS idx_ohlc_daily_date ON ohlc_daily(date);
CREATE INDEX IF NOT EXISTS idx_ohlc_daily_symbol_date ON ohlc_daily(trading_symbol, date);
CREATE INDEX IF NOT EXISTS idx_ohlc_intraday_instrument ON ohlc_intraday(instrument_key);
CREATE INDEX IF NOT EXISTS idx_ohlc_intraday_timestamp ON ohlc_intraday(timestamp);
CREATE INDEX IF NOT EXISTS idx_ohlc_intraday_symbol_date ON ohlc_intraday(trading_symbol, date);
CREATE INDEX IF NOT EXISTS idx_ohlc_refresh_history_symbol_date ON ohlc_refresh_history(trading_symbol, date);

-- Insert initial master data
INSERT INTO brokers (broker_code, broker_name) VALUES 
('UPSTOX', 'Upstox'),
('ZERODHA', 'Zerodha')
ON CONFLICT (broker_code) DO NOTHING;

INSERT INTO exchanges (exchange_code, exchange_name) VALUES 
('NSE', 'National Stock Exchange'),
('BSE', 'Bombay Stock Exchange'),
('MCX', 'Multi Commodity Exchange')
ON CONFLICT (exchange_code) DO NOTHING;

INSERT INTO instrument_types (type_code, type_name, category) VALUES 
('EQ', 'Equity', 'EQUITY'),
('FUT', 'Futures', 'DERIVATIVES'),
('CE', 'Call Options', 'DERIVATIVES'),
('PE', 'Put Options', 'DERIVATIVES'),
('INDEX', 'Index', 'INDEX'),
('MTF', 'Margin Trading Facility', 'EQUITY'),
('MIS', 'Margin Intraday Square-off', 'EQUITY')
ON CONFLICT (type_code) DO NOTHING;

-- Function to update last_updated timestamp
CREATE OR REPLACE FUNCTION update_instruments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update last_updated
CREATE TRIGGER trigger_update_instruments_updated_at
    BEFORE UPDATE ON instruments
    FOR EACH ROW
    EXECUTE FUNCTION update_instruments_updated_at();

-- Function to update OHLC data timestamps
CREATE OR REPLACE FUNCTION update_ohlc_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update OHLC updated_at
CREATE TRIGGER trigger_update_ohlc_updated_at
    BEFORE UPDATE ON ohlc_daily
    FOR EACH ROW
    EXECUTE FUNCTION update_ohlc_updated_at();

-- Create a simple test function to verify Python integration
CREATE OR REPLACE FUNCTION test_python()
RETURNS text
LANGUAGE plpython3u
AS $$
import requests
try:
    # Test if requests is available
    response = requests.get('https://httpbin.org/get', timeout=5)
    return f"Python integration working! HTTP status: {response.status_code}"
except Exception as e:
    return f"Python integration error: {str(e)}"
$$;

-- Create system info table for monitoring
CREATE TABLE IF NOT EXISTS system_info (
    id SERIAL PRIMARY KEY,
    info_type VARCHAR(100) NOT NULL,
    info_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial system info
INSERT INTO system_info (info_type, info_value) VALUES 
    ('database_created', CURRENT_TIMESTAMP::text),
    ('python_extension', 'plpython3u'),
    ('postgres_version', version()),
    ('schema_version', '1.0.0'),
    ('tables_created', '9'),
    ('indexes_created', '13');

-- Test the Python function
SELECT test_python() as python_test_result;
