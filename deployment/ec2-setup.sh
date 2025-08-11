#!/bin/bash

# EC2 Setup Script for Todo Backend
# Run this script on your EC2 instance after connecting via SSH

echo "Setting up Todo Backend on EC2..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and pip
sudo apt install -y python3 python3-pip python3-venv

# Install MySQL client (for database connectivity)
sudo apt install -y mysql-client

# Create application directory
sudo mkdir -p /opt/todo-backend
sudo chown ubuntu:ubuntu /opt/todo-backend
cd /opt/todo-backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install flask flask-cors flask-sqlalchemy pymysql python-dotenv gunicorn

# Create systemd service file
sudo tee /etc/systemd/system/todo-backend.service > /dev/null <<EOF
[Unit]
Description=Todo Backend Flask App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/todo-backend
Environment="PATH=/opt/todo-backend/venv/bin"
ExecStart=/opt/todo-backend/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable todo-backend
sudo systemctl start todo-backend

echo "Todo Backend service installed and started!"
echo "Check status with: sudo systemctl status todo-backend"
echo "View logs with: sudo journalctl -u todo-backend -f"
