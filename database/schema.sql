-- Todo Application Database Schema
-- MySQL 8.0+

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS todo_db;
USE todo_db;

-- Drop table if exists (for clean setup)
DROP TABLE IF EXISTS todos;

-- Create todos table
CREATE TABLE todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_completed (completed),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data
INSERT INTO todos (title, description, completed) VALUES
('Complete Project Setup', 'Set up the development environment and install all dependencies', FALSE),
('Design Database Schema', 'Create the MySQL database schema for the todo application', TRUE),
('Build Backend API', 'Develop the Flask REST API with all CRUD operations', FALSE),
('Create Frontend UI', 'Build the Flutter web interface with modern design', FALSE),
('Test Application', 'Write comprehensive tests for all components', FALSE),
('Deploy to AWS', 'Deploy the application using AWS services (S3, ECS, RDS)', FALSE);

-- Create a user for the application (optional - for production)
-- CREATE USER 'todo_user'@'%' IDENTIFIED BY 'your_secure_password';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON todo_db.* TO 'todo_user'@'%';
-- FLUSH PRIVILEGES; 