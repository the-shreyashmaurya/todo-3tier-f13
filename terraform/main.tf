terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket
resource "aws_s3_bucket" "project_bucket" {
  bucket = "${var.project_name}-bucket-${data.aws_caller_identity.current.account_id}"
}

# Random password for RDS
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!@#%&*"
}

# RDS Parameter Group (Enable IAM Auth)
resource "aws_db_parameter_group" "rds_pg" {
  name   = "${var.project_name}-pg"
  family = "mysql8.0"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "local_infile"
    value = "0"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = data.aws_subnets.all.ids
}

# Get all subnets
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group for EC2 & RDS
resource "aws_security_group" "project_sg" {
  name   = "${var.project_name}-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Instance with IAM Auth
resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  username             = var.db_username
  password             = random_password.db_password.result
  parameter_group_name = aws_db_parameter_group.rds_pg.name
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids = [aws_security_group.project_sg.id]
  skip_final_snapshot  = true
}

# EC2 Instance
resource "aws_instance" "ec2" {
  ami                    = "ami-04b70fa74e45c3917" # Amazon Linux 2 in us-east-1
  instance_type          = var.ec2_instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.project_sg.id]

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
