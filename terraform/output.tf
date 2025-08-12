output "ec2_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.project_bucket.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}
