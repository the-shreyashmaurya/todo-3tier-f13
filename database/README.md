# Database Layer

This folder contains the database setup and migration scripts for the Todo application.

## Database Schema

The application uses a simple but scalable MySQL schema:

### Tables

1. **todos** - Main todo items table
   - `id` (Primary Key, Auto Increment)
   - `title` (VARCHAR) - Todo title
   - `description` (TEXT) - Todo description
   - `completed` (BOOLEAN) - Completion status
   - `created_at` (TIMESTAMP) - Creation timestamp
   - `updated_at` (TIMESTAMP) - Last update timestamp

## Setup Instructions

### Local Development

1. **Install MySQL**
   - Download and install MySQL 8.0+ from [mysql.com](https://dev.mysql.com/downloads/)
   - Or use Docker: `docker run --name mysql-todo -e MYSQL_ROOT_PASSWORD=password -e MYSQL_DATABASE=todo_db -p 3306:3306 -d mysql:8.0`

2. **Create Database**
   ```sql
   CREATE DATABASE todo_db;
   USE todo_db;
   ```

3. **Run Migration**
   ```bash
   mysql -u root -p todo_db < schema.sql
   ```

### AWS RDS Setup

See `deployment/aws-setup.md` for detailed AWS RDS configuration.

## Files

- `schema.sql` - Database schema and initial data
- `sample_data.sql` - Sample todo data for testing 