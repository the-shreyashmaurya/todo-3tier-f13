# Deployment Checklist

## Pre-deployment
- [ ] AWS Account ready
- [ ] Flutter SDK installed locally
- [ ] MySQL Workbench installed (optional)
- [ ] SSH client available

## Database (RDS)
- [ ] RDS MySQL instance created
- [ ] Security group configured (allow MySQL 3306)
- [ ] Database schema created using `database/schema.sql`
- [ ] Database connection tested

## Backend (EC2)
- [ ] EC2 instance launched (Ubuntu 22.04 LTS, t2.micro)
- [ ] Security group configured (SSH 22, HTTP 80, HTTPS 443, Custom 5000)
- [ ] Backend files uploaded to EC2
- [ ] Setup script run: `ec2-setup.sh`
- [ ] Service started and running: `sudo systemctl status todo-backend`
- [ ] API health check passed: `curl http://localhost:5000/api/health`
- [ ] Database connection working from EC2

## Frontend (S3 + CloudFront)
- [ ] API URL updated in frontend code
- [ ] Flutter web app built: `flutter build web --release`
- [ ] S3 bucket created with static website hosting
- [ ] Frontend files uploaded to S3
- [ ] S3 bucket policy configured for public access
- [ ] CloudFront distribution created (optional)
- [ ] Frontend accessible via S3 website URL

## Testing
- [ ] Backend API accessible from internet
- [ ] Frontend loads without errors
- [ ] Create todo functionality works
- [ ] Edit todo functionality works
- [ ] Delete todo functionality works
- [ ] Toggle todo completion works
- [ ] No CORS errors in browser console

## Security
- [ ] RDS security group restricts access to EC2 only
- [ ] EC2 security group allows only necessary ports
- [ ] Database credentials not exposed in logs
- [ ] HTTPS enabled (if using CloudFront)

## Monitoring
- [ ] EC2 service logs monitored: `sudo journalctl -u todo-backend -f`
- [ ] RDS monitoring enabled
- [ ] CloudWatch metrics configured (optional)

## Cost Optimization
- [ ] Using free tier resources where possible
- [ ] EC2 instance stopped when not in use
- [ ] S3 lifecycle policies configured (optional)

## Post-deployment
- [ ] Application URL documented
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured
- [ ] Documentation updated
