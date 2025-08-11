#!/bin/bash

# Quick Start Script for Local Development
# This script helps you run the Todo application locally

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}3-Tier Todo App - Local Development${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}Docker is not running. Please start Docker Desktop first.${NC}"
    exit 1
fi

# Function to check if a port is in use
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${YELLOW}Port $1 is already in use. Please stop the service using port $1 first.${NC}"
        exit 1
    fi
}

# Check ports
check_port 3306
check_port 5000
check_port 8080

echo -e "${BLUE}Starting MySQL Database...${NC}"
# Start MySQL container
docker run --name todo-mysql \
    -e MYSQL_ROOT_PASSWORD=password \
    -e MYSQL_DATABASE=todo_db \
    -p 3306:3306 \
    -d mysql:8.0

echo -e "${GREEN}MySQL started on port 3306${NC}"

# Wait for MySQL to be ready
echo -e "${BLUE}Waiting for MySQL to be ready...${NC}"
sleep 10

# Initialize database
echo -e "${BLUE}Initializing database...${NC}"
mysql -h localhost -P 3306 -u root -ppassword todo_db < database/schema.sql
echo -e "${GREEN}Database initialized!${NC}"

echo -e "${BLUE}Starting Flask Backend...${NC}"
# Start Flask backend
cd backend
python -m venv venv
source venv/bin/activate  # On Windows, use: venv\Scripts\activate
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL="mysql+pymysql://root:password@localhost:3306/todo_db"
export FLASK_ENV="development"

# Start Flask app in background
python app.py &
BACKEND_PID=$!
cd ..

echo -e "${GREEN}Backend started on port 5000${NC}"

# Wait for backend to be ready
echo -e "${BLUE}Waiting for backend to be ready...${NC}"
sleep 5

echo -e "${BLUE}Starting Flutter Frontend...${NC}"
# Start Flutter frontend
cd frontend
flutter pub get
flutter run -d chrome --web-port 8080 &
FRONTEND_PID=$!
cd ..

echo -e "${GREEN}Frontend started on port 8080${NC}"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Application Started Successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo -e "Frontend: ${GREEN}http://localhost:8080${NC}"
echo -e "Backend API: ${GREEN}http://localhost:5000${NC}"
echo -e "Database: ${GREEN}localhost:3306${NC}"
echo ""
echo -e "${BLUE}API Endpoints:${NC}"
echo -e "Health Check: ${GREEN}http://localhost:5000/api/health${NC}"
echo -e "Todos: ${GREEN}http://localhost:5000/api/todos${NC}"
echo ""
echo -e "${YELLOW}To stop the application, press Ctrl+C${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${BLUE}Stopping application...${NC}"
    
    # Stop Flask backend
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi
    
    # Stop Flutter frontend
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi
    
    # Stop MySQL container
    docker stop todo-mysql 2>/dev/null || true
    docker rm todo-mysql 2>/dev/null || true
    
    echo -e "${GREEN}Application stopped!${NC}"
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM

# Keep script running
wait 