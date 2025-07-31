-- Database initialization script
-- This script creates multiple databases for our microservices

-- Create databases for each microservice
CREATE DATABASE auth;
CREATE DATABASE products;  
CREATE DATABASE orders;

-- Create users and grant permissions (optional, for better security)
CREATE USER auth_user WITH ENCRYPTED PASSWORD 'auth_password';
CREATE USER products_user WITH ENCRYPTED PASSWORD 'products_password';
CREATE USER orders_user WITH ENCRYPTED PASSWORD 'orders_password';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE auth TO auth_user;
GRANT ALL PRIVILEGES ON DATABASE products TO products_user;
GRANT ALL PRIVILEGES ON DATABASE orders TO orders_user;

-- Connect to each database and grant schema permissions
\c auth;
GRANT ALL ON SCHEMA public TO auth_user;

\c products;
GRANT ALL ON SCHEMA public TO products_user;

\c orders;
GRANT ALL ON SCHEMA public TO orders_user;
