variable "project_name" {
  description = "Project name prefix for all resources"
  default     = "todo"
}

variable "db_username" {
  description = "Master username for RDS"
  default     = "admin"
}

variable "db_instance_class" {
  description = "RDS instance type"
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "Database engine"
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  default     = "8.0.41"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}
