# Todo App EC2 Deployment Guide

## Architecture Overview
- **Frontend**: Flutter Web → S3 + CloudFront
- **Backend**: Python Flask → EC2 Instance
- **Database**: MySQL → AWS RDS

## Prerequisites
- AWS Account
- AWS CLI configured (optional)
- Flutter SDK installed locally
- MySQL Workbench (for database setup)

## Step 1: Database Setup (RDS)

### 1.1 Create RDS MySQL Instance
1. Go to AWS Console → RDS → Create database
2. Choose MySQL
3. Template: Free tier (if available) or Production
4. Settings:
   - DB instance identifier: `todo-db`
   - Master username: `shreyash`
   - Master password: `xyz`
5. Instance configuration: db.t3.micro (free tier)
6. Storage: 20 GB (free tier)
7. Connectivity:
   - VPC: Default VPC
   - Public access: Yes
   - VPC security group: Create new (todo-db-sg)
   - Availability Zone: ap-south-1a
8. Database authentication: Password authentication
9. Create database

### 1.2 Configure Security Group
1. Go to EC2 → Security Groups
2. Find `todo-db-sg`
3. Edit inbound rules:
   - Add rule: MySQL/Aurora (3306)
   - Source: Custom → 0.0.0.0/0 (for demo) or your EC2 security group

### 1.3 Setup Database Schema
1. Open MySQL Workbench
2. Connect to your RDS endpoint: `todo-db.cro088wagfps.ap-south-1.rds.amazonaws.com`
3. Username: `shreyash`, Password: `xyz`
4. Run the SQL script from `database/schema.sql`

## Step 2: Backend Deployment (EC2)

### 2.1 Launch EC2 Instance
1. Go to AWS Console → EC2 → Launch Instance
2. Name: `todo-backend`
3. AMI: Amazon Linux 2023 or Ubuntu Server 22.04 LTS
4. Instance type: t2.micro (free tier)
5. Key pair: Create new or use existing
6. Network settings:
   - VPC: Default VPC
   - Subnet: Public subnet
   - Auto-assign public IP: Enable
   - Security group: Create new (todo-backend-sg)
7. Storage: 8 GB (free tier)
8. Launch instance

### 2.2 Configure EC2 Security Group
1. Go to EC2 → Security Groups
2. Find `todo-backend-sg`
3. Edit inbound rules:
   - SSH (22): Your IP or 0.0.0.0/0
   - HTTP (80): 0.0.0.0/0
   - HTTPS (443): 0.0.0.0/0
   - Custom TCP (5000): 0.0.0.0/0 (Flask app)

### 2.3 Deploy Backend Code
1. Connect to EC2 via SSH:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-public-ip
   ```

2. Upload backend files:
   ```bash
   # On your local machine
   scp -i your-key.pem -r backend/* ubuntu@your-ec2-public-ip:/tmp/
   ```

3. On EC2, run the setup script:
   ```bash
   # Copy files to proper location
   sudo cp -r /tmp/* /opt/todo-backend/
   
   # Make setup script executable and run
   chmod +x /opt/todo-backend/ec2-setup.sh
   /opt/todo-backend/ec2-setup.sh
   ```

4. Verify the service is running:
   ```bash
   sudo systemctl status todo-backend
   sudo journalctl -u todo-backend -f
   ```

5. Test the API:
   ```bash
   curl http://localhost:5000/api/health
   ```

### 2.4 Setup Nginx (Optional - for production)
```bash
sudo apt install nginx
sudo tee /etc/nginx/sites-available/todo-backend > /dev/null <<EOF
server {
    listen 80;
    server_name your-ec2-public-ip;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/todo-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 3: Frontend Deployment (S3 + CloudFront)

### 3.1 Update API URL
1. Edit `frontend/lib/services/api_service.dart`
2. Update the baseUrl to your EC2 public IP:
   ```dart
   // In main.dart or where ApiService is initialized
   ApiService(baseUrl: 'http://your-ec2-public-ip:5000/api')
   ```

### 3.2 Build Flutter Web
```bash
cd frontend
flutter build web --release
```

### 3.3 Deploy to S3
1. Create S3 bucket:
   - Name: `todo-frontend-your-account-id`
   - Region: ap-south-1
   - Block public access: Uncheck all

2. Enable static website hosting:
   - Properties → Static website hosting → Enable
   - Index document: `index.html`
   - Error document: `index.html`

3. Upload files:
   - Upload all files from `frontend/build/web/` to S3 bucket

4. Set bucket policy for public access:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::todo-frontend-your-account-id/*"
        }
    ]
}
```

### 3.4 Setup CloudFront (Optional)
1. Go to CloudFront → Create distribution
2. Origin domain: S3 website endpoint
3. Viewer protocol policy: Redirect HTTP to HTTPS
4. Default root object: `index.html`
5. Create distribution

## Step 4: Testing

### 4.1 Test Backend
```bash
# Health check
curl http://your-ec2-public-ip:5000/api/health

# Test CRUD operations
curl -X POST http://your-ec2-public-ip:5000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Todo","description":"Test Description"}'
```

### 4.2 Test Frontend
1. Open S3 website URL or CloudFront URL
2. Try creating, editing, and deleting todos
3. Check browser console for any errors

## Troubleshooting

### Backend Issues
1. Check service status: `sudo systemctl status todo-backend`
2. View logs: `sudo journalctl -u todo-backend -f`
3. Check firewall: `sudo ufw status`
4. Test database connection: `mysql -h todo-db.cro088wagfps.ap-south-1.rds.amazonaws.com -u shreyash -p`

### Frontend Issues
1. Check API URL in browser console
2. Verify CORS settings in backend
3. Check S3 bucket permissions
4. Clear browser cache

### Security Notes
- For production, use HTTPS
- Restrict security group rules to specific IPs
- Use AWS Secrets Manager for database credentials
- Enable CloudTrail for audit logs

## Cost Optimization
- Use free tier resources where possible
- Stop EC2 instance when not in use
- Use S3 lifecycle policies for old data
- Monitor CloudWatch metrics
