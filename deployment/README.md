# AWS Deployment Guide

This guide will walk you through deploying the 3-tier Todo application to AWS using:
- **Frontend**: AWS S3 + CloudFront CDN
- **Backend**: AWS EC2 Instance
- **Database**: AWS RDS MySQL

## Prerequisites

1. **AWS Account**: You need an active AWS account
2. **Flutter SDK**: For building the frontend
3. **MySQL Workbench**: For database setup (optional)
4. **SSH Client**: For connecting to EC2

## Architecture Overview

```
Internet → CloudFront → S3 (Frontend)
                ↓
            EC2 Instance (Backend)
                ↓
            RDS MySQL (Database)
```

## Quick Start

For detailed step-by-step instructions, see [EC2 Deployment Guide](ec2-deployment-guide.md)

## Step-by-Step Deployment

### 1. Database Setup (RDS MySQL)

1. **Create RDS Instance**
   - Go to AWS RDS Console
   - Click "Create database"
   - Choose "Standard create"
   - Select "MySQL" engine
   - Choose "Free tier" for development
   - Set database name: `todo_db`
   - Set master username: `shreyash`
   - Set master password: `xyz`
   - Choose VPC and security group
   - Click "Create database"

2. **Configure Security Group**
   - Allow inbound MySQL (3306) from EC2 security group
   - Allow inbound from your IP for initial setup

3. **Initialize Database**
   - Use MySQL Workbench to connect to RDS
   - Run the SQL script from `database/schema.sql`

### 2. Backend Setup (EC2)

1. **Launch EC2 Instance**
   - Go to EC2 Console
   - Launch instance with Ubuntu 22.04 LTS
   - Instance type: t2.micro (free tier)
   - Configure security group for SSH and HTTP
   - Launch and connect via SSH

2. **Deploy Backend Code**
   ```bash
   # Upload backend files to EC2
   scp -i your-key.pem -r backend/* ubuntu@your-ec2-ip:/tmp/
   
   # Run setup script on EC2
   ssh -i your-key.pem ubuntu@your-ec2-ip
   sudo cp -r /tmp/* /opt/todo-backend/
   chmod +x /opt/todo-backend/ec2-setup.sh
   /opt/todo-backend/ec2-setup.sh
   ```

3. **Verify Backend**
   ```bash
   # Check service status
   sudo systemctl status todo-backend
   
   # Test API
   curl http://localhost:5000/api/health
   ```

### 3. Frontend Setup (S3 + CloudFront)

1. **Build Flutter Web App**
   ```bash
   cd frontend
   # Update API URL in lib/services/api_service.dart
   flutter build web --release
   ```

2. **Create S3 Bucket**
   - Create bucket: "todo-frontend-your-account-id"
   - Enable static website hosting
   - Set index document: "index.html"
   - Upload files from `build/web/`

3. **Create CloudFront Distribution**
   - Origin: S3 bucket
   - Enable HTTPS
   - Set default root object: "index.html"

## Environment Configuration

1. **Update Frontend API URL**
   - Edit `frontend/lib/services/api_service.dart`
   - Change API URL to your EC2 public IP

2. **Backend Configuration**
   - Database URL is already configured in `app.py`
   - CORS is enabled for all origins

## Security Best Practices

1. **Use IAM Roles**: Don't use access keys
2. **Enable VPC**: Isolate resources
3. **Use HTTPS**: Enable SSL/TLS everywhere
4. **Regular Updates**: Keep dependencies updated
5. **Monitoring**: Set up CloudWatch alerts

## Cost Optimization

1. **Use Free Tier**: RDS, EC2, S3 have free tiers
2. **Right-size Resources**: Start small, scale as needed
3. **Stop EC2**: When not in use to save costs
4. **S3 Lifecycle**: Archive old data

## Monitoring and Maintenance

1. **CloudWatch**: Monitor application metrics
2. **Logs**: Check EC2 logs with `journalctl`
3. **Backups**: Automated RDS backups
4. **Updates**: Regular security patches

## Troubleshooting

### Common Issues

1. **CORS Errors**: Check backend CORS configuration
2. **Database Connection**: Verify security group rules
3. **EC2 Service**: Check service status with `systemctl`
4. **Frontend Not Loading**: Verify S3 bucket permissions

### Useful Commands

```bash
# Check EC2 service status
sudo systemctl status todo-backend

# View application logs
sudo journalctl -u todo-backend -f

# Test database connection
mysql -h todo-db.cro088wagfps.ap-south-1.rds.amazonaws.com -u shreyash -p

# Check EC2 security group
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

## Next Steps

1. **Custom Domain**: Set up Route 53
2. **SSL Certificate**: Request ACM certificate
3. **CI/CD Pipeline**: Set up GitHub Actions
4. **Monitoring**: Add CloudWatch dashboards
5. **Backup Strategy**: Implement automated backups

## Support

For issues or questions:
1. Check AWS documentation
2. Review EC2 logs with `journalctl`
3. Test components individually
4. Use AWS support (if available) 