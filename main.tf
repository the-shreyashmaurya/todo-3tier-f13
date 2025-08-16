# terraform {
#   required_version = ">= 1.6.0"
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.48"
#     }
#     random = {
#       source  = "hashicorp/random"
#       version = ">= 3.6"
#     }
#   }
# }

# variable "project" {
#   default = "todo3tier-final"
# }

# variable "primary_region" {
#   default = "ap-south-1"
# }

# variable "dr_region" {
#   default = "ap-southeast-1"
# }

# locals {
#   rand = random_string.suffix.result
#   tags = {
#     Project = var.project
#   }
# }

# resource "random_string" "suffix" {
#   length  = 5
#   upper   = false
#   lower   = true
#   numeric = true
#   special = false
# }

# # Providers
# provider "aws" {
#   region = var.primary_region
# }

# provider "aws" {
#   alias  = "primary"
#   region = var.primary_region
# }

# provider "aws" {
#   alias  = "dr"
#   region = var.dr_region
# }

# # Default VPCs
# data "aws_vpc" "primary" {
#   provider = aws.primary
#   default  = true
# }

# data "aws_vpc" "dr" {
#   provider = aws.dr
#   default  = true
# }

# data "aws_subnets" "primary" {
#   provider = aws.primary
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.primary.id]
#   }
# }

# data "aws_subnets" "dr" {
#   provider = aws.dr
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.dr.id]
#   }
# }

# locals {
#   primary_subnet = element(data.aws_subnets.primary.ids, 0)
#   dr_subnet      = element(data.aws_subnets.dr.ids, 0)
# }

# # Security Groups
# resource "aws_security_group" "alb_primary_sg" {
#   provider = aws.primary
#   vpc_id   = data.aws_vpc.primary.id
#   ingress { from_port=80 to_port=80 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
#   egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
# }

# resource "aws_security_group" "alb_dr_sg" {
#   provider = aws.dr
#   vpc_id   = data.aws_vpc.dr.id
#   ingress { from_port=80 to_port=80 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
#   egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
# }

# resource "aws_security_group" "app_primary_sg" {
#   provider = aws.primary
#   vpc_id   = data.aws_vpc.primary.id
#   ingress { from_port=5000 to_port=5000 protocol="tcp" security_groups=[aws_security_group.alb_primary_sg.id] }
#   egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
# }

# resource "aws_security_group" "app_dr_sg" {
#   provider = aws.dr
#   vpc_id   = data.aws_vpc.dr.id
#   ingress { from_port=5000 to_port=5000 protocol="tcp" security_groups=[aws_security_group.alb_dr_sg.id] }
#   egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
# }

# # AMIs
# data "aws_ami" "amzn2_primary" {
#   provider    = aws.primary
#   owners      = ["amazon"]
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# data "aws_ami" "amzn2_dr" {
#   provider    = aws.dr
#   owners      = ["amazon"]
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# # User Data (real backend)
# locals {
#   user_data = <<-EOT
#               #!/bin/bash
#               set -xe
#               apt-get update -y && apt-get upgrade -y
#               apt-get install -y git python3 python3-pip python3-venv mysql-client unzip
#               cd /home/ubuntu
#               rm -rf todo-3tier-f13 || true
#               git clone https://github.com/the-shreyashmaurya/todo-3tier-f13.git
#               mkdir -p /opt/todo-backend
#               cp -r /home/ubuntu/todo-3tier-f13/backend /opt/todo-backend/
#               cd /opt/todo-backend
#               python3 -m venv venv
#               /opt/todo-backend/venv/bin/pip install --upgrade pip
#               if [ -f /opt/todo-backend/backend/requirements.txt ]; then
#                 /opt/todo-backend/venv/bin/pip install -r /opt/todo-backend/backend/requirements.txt
#               fi
#               cat > /etc/systemd/system/todo-backend.service <<'EOF'
#               [Unit]
#               Description=Todo Backend Flask App
#               After=network.target
#               [Service]
#               User=ubuntu
#               WorkingDirectory=/opt/todo-backend/backend
#               Environment="PATH=/opt/todo-backend/venv/bin"
#               ExecStart=/opt/todo-backend/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
#               Restart=always
#               [Install]
#               WantedBy=multi-user.target
#               EOF
#               systemctl daemon-reload
#               systemctl enable todo-backend
#               systemctl start todo-backend
#               curl -s http://127.0.0.1:5000/api/health || true
#               EOT
# }

# # EC2 instances (no ASG)
# resource "aws_instance" "primary" {
#   provider          = aws.primary
#   ami               = data.aws_ami.amzn2_primary.id
#   instance_type     = "t3.micro"
#   subnet_id         = local.primary_subnet
#   vpc_security_group_ids = [aws_security_group.app_primary_sg.id]
#   user_data         = local.user_data
#   tags              = merge(local.tags, { Role = "app-primary" })
# }

# resource "aws_instance" "dr" {
#   provider          = aws.dr
#   ami               = data.aws_ami.amzn2_dr.id
#   instance_type     = "t3.micro"
#   subnet_id         = local.dr_subnet
#   vpc_security_group_ids = [aws_security_group.app_dr_sg.id]
#   user_data         = local.user_data
#   tags              = merge(local.tags, { Role = "app-dr" })
# }

# # Outputs
# output "primary_instance_public_ip" {
#   value = aws_instance.primary.public_ip
# }

# output "dr_instance_public_ip" {
#   value = aws_instance.dr.public_ip
# }

















































# # ============================================================================
# # Simplified Active–Passive DR on DEFAULT AWS RESOURCES (single file)
# # Primary: ap-south-1 (Mumbai) | DR: ap-southeast-1 (Singapore)
# # Uses: Default VPC + default subnets where possible, minimal SGs, ALB+ASG, RDS
# # Frontend: S3 (Primary) -> CRR -> S3 (DR) behind CloudFront Origin Failover
# # API:      ALB (Primary) + ALB (DR) behind CloudFront Origin Failover
# # ============================================================================

# terraform {
#   required_version = ">= 1.6.0"
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.48"
#     }
#     random = {
#       source  = "hashicorp/random"
#       version = ">= 3.6"
#     }
#   }
# }

# # ---------------------------------------------------------------------------
# # Variables
# # ---------------------------------------------------------------------------
# variable "project" {
#   description = "Project name prefix (e.g., todo3tier)"
#   type        = string
#   default     = "todo3tier"
# }

# variable "primary_region" {
#   type    = string
#   default = "ap-south-1" # Mumbai
# }

# variable "dr_region" {
#   type    = string
#   default = "ap-southeast-1" # Singapore
# }

# variable "config_by_workspace" {
#   description = "Per-workspace sizing"
#   type = map(object({
#     asg_min_primary = number
#     asg_max_primary = number
#     asg_min_dr      = number
#     asg_max_dr      = number
#     instance_type   = string
#     db_instance     = string
#     db_alloc_gb     = number
#     db_username     = string
#     db_password     = string
#   }))
#   default = {
#     dev = {
#       asg_min_primary = 1
#       asg_max_primary = 2
#       asg_min_dr      = 0
#       asg_max_dr      = 2
#       instance_type   = "t3.micro"
#       db_instance     = "db.t3.micro"
#       db_alloc_gb     = 20
#       db_username     = "appuser"
#       db_password     = "DevPassw0rd!"
#     }
#     prod = {
#       asg_min_primary = 2
#       asg_max_primary = 4
#       asg_min_dr      = 0
#       asg_max_dr      = 4
#       instance_type   = "t3.small"
#       db_instance     = "db.t3.small"
#       db_alloc_gb     = 50
#       db_username     = "appuser"
#       db_password     = "ChangeMe!123"
#     }
#   }
# }

# locals {
#   ws      = terraform.workspace
#   cfg     = lookup(var.config_by_workspace, local.ws, var.config_by_workspace["dev"]) # default to dev
#   rand    = random_string.suffix.result
#   tags = {
#     Project   = var.project
#     Workspace = local.ws
#   }
# }

# resource "random_string" "suffix" {
#   length  = 5
#   upper   = false
#   lower   = true
#   numeric = true
#   special = false
# }

# # ---------------------------------------------------------------------------
# # Providers (Default regions set above)
# # ---------------------------------------------------------------------------
# provider "aws" {
#   region = var.primary_region
# }

# provider "aws" {
#   alias  = "primary"
#   region = var.primary_region
# }

# provider "aws" {
#   alias  = "dr"
#   region = var.dr_region
# }

# # ---------------------------------------------------------------------------
# # Default VPC + Default Subnets (in both regions)
# # ---------------------------------------------------------------------------
# # Use the default VPCs/subnets; no custom networking unless necessary.

# data "aws_vpc" "primary" {
#   provider = aws.primary
#   default  = true
# }

# data "aws_vpc" "dr" {
#   provider = aws.dr
#   default  = true
# }

# data "aws_subnets" "primary_default" {
#   provider = aws.primary
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.primary.id]
#   }
#   filter {
#     name   = "default-for-az"
#     values = ["true"]
#   }
# }

# data "aws_subnets" "dr_default" {
#   provider = aws.dr
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.dr.id]
#   }
#   filter {
#     name   = "default-for-az"
#     values = ["true"]
#   }
# }

# # Pick at least two default subnets per region
# locals {
#   primary_subnets = slice(data.aws_subnets.primary_default.ids, 0, 2)
#   dr_subnets      = slice(data.aws_subnets.dr_default.ids, 0, 2)
# }

# # ---------------------------------------------------------------------------
# # Security Groups (minimal)
# # ---------------------------------------------------------------------------
# resource "aws_security_group" "alb_primary_sg" {
#   provider = aws.primary
#   name     = "${var.project}-alb-primary-${local.rand}"
#   vpc_id   = data.aws_vpc.primary.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# resource "aws_security_group" "alb_dr_sg" {
#   provider = aws.dr
#   name     = "${var.project}-alb-dr-${local.rand}"
#   vpc_id   = data.aws_vpc.dr.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# resource "aws_security_group" "app_primary_sg" {
#   provider = aws.primary
#   name     = "${var.project}-app-primary-${local.rand}"
#   vpc_id   = data.aws_vpc.primary.id
#   ingress {
#     from_port   = 5000
#     to_port     = 5000
#     protocol    = "tcp"
#     security_groups = [aws_security_group.alb_primary_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# resource "aws_security_group" "app_dr_sg" {
#   provider = aws.dr
#   name     = "${var.project}-app-dr-${local.rand}"
#   vpc_id   = data.aws_vpc.dr.id
#   ingress {
#     from_port   = 5000
#     to_port     = 5000
#     protocol    = "tcp"
#     security_groups = [aws_security_group.alb_dr_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# resource "aws_security_group" "rds_primary_sg" {
#   provider = aws.primary
#   name     = "${var.project}-rds-primary-${local.rand}"
#   vpc_id   = data.aws_vpc.primary.id
#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     security_groups = [aws_security_group.app_primary_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# resource "aws_security_group" "rds_dr_sg" {
#   provider = aws.dr
#   name     = "${var.project}-rds-dr-${local.rand}"
#   vpc_id   = data.aws_vpc.dr.id
#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     security_groups = [aws_security_group.app_dr_sg.id]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = local.tags
# }

# # ---------------------------------------------------------------------------
# # AMIs (latest Amazon Linux 2 in each region)
# # ---------------------------------------------------------------------------
# data "aws_ami" "amzn2_primary" {
#   provider    = aws.primary
#   owners      = ["amazon"]
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# data "aws_ami" "amzn2_dr" {
#   provider    = aws.dr
#   owners      = ["amazon"]
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# # ---------------------------------------------------------------------------
# # Launch Templates + ASGs + ALBs (Flask demo app on :5000 with /healthz)
# # ---------------------------------------------------------------------------
# locals {
#   user_data = <<-EOT
#               #!/bin/bash
#               set -xe

#               # Update system
#               apt-get update -y && apt-get upgrade -y

#               # Install dependencies
#               apt-get install -y git python3 python3-pip python3-venv mysql-client unzip

#               # Clone your repo (ensure instance has internet)
#               cd /home/ubuntu
#               rm -rf todo-3tier-f13 || true
#               git clone https://github.com/the-shreyashmaurya/todo-3tier-f13.git

#               # Prepare application directories
#               mkdir -p /opt/todo-backend
#               cp -r /home/ubuntu/todo-3tier-f13/backend /opt/todo-backend/

#               # Create virtual environment and install deps
#               cd /opt/todo-backend
#               python3 -m venv venv
#               /opt/todo-backend/venv/bin/pip install --upgrade pip
#               if [ -f /opt/todo-backend/backend/requirements.txt ]; then
#                 /opt/todo-backend/venv/bin/pip install -r /opt/todo-backend/backend/requirements.txt
#               fi

#               # Create systemd service file
#               cat > /etc/systemd/system/todo-backend.service <<'EOF'
#               [Unit]
#               Description=Todo Backend Flask App
#               After=network.target

#               [Service]
#               User=ubuntu
#               WorkingDirectory=/opt/todo-backend/backend
#               Environment="PATH=/opt/todo-backend/venv/bin"
#               ExecStart=/opt/todo-backend/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
#               Restart=always

#               [Install]
#               WantedBy=multi-user.target
#               EOF

#               # Reload systemd and enable service
#               systemctl daemon-reload
#               systemctl enable todo-backend
#               systemctl start todo-backend

#               # Health check
#               curl -s http://127.0.0.1:5000/api/health || true
#               EOT
# }

# resource "aws_launch_template" "primary" {
#   provider      = aws.primary
#   name_prefix   = "${var.project}-lt-primary-"
#   image_id      = data.aws_ami.amzn2_primary.id
#   instance_type = local.cfg.instance_type
#   vpc_security_group_ids = [aws_security_group.app_primary_sg.id]
#   user_data     = base64encode(local.user_data)
#   tag_specifications {
#     resource_type = "instance"
#     tags          = merge(local.tags, { Role = "app-primary" })
#   }
# }

# resource "aws_lb" "primary" {
#   provider           = aws.primary
#   name               = "${var.project}-alb-primary-${local.rand}"
#   load_balancer_type = "application"
#   subnets            = local.primary_subnets
#   security_groups    = [aws_security_group.alb_primary_sg.id]
#   tags               = local.tags
# }

# resource "aws_lb_target_group" "primary" {
#   provider = aws.primary
#   name     = "${var.project}-tg-primary-${local.rand}"
#   port     = 5000
#   protocol = "HTTP"
#   vpc_id   = data.aws_vpc.primary.id
#   health_check {
#     path                = "/api/health"
#     matcher             = "200"
#     interval            = 15
#     healthy_threshold   = 2
#     unhealthy_threshold = 3
#     timeout             = 5
#   }
#   tags = local.tags
# }

# resource "aws_lb_listener" "primary_http" {
#   provider          = aws.primary
#   load_balancer_arn = aws_lb.primary.arn
#   port              = 80
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.primary.arn
#   }
# }

# resource "aws_autoscaling_group" "primary" {
#   provider                  = aws.primary
#   name                      = "${var.project}-asg-primary-${local.rand}"
#   min_size                  = local.cfg.asg_min_primary
#   max_size                  = local.cfg.asg_max_primary
#   desired_capacity          = local.cfg.asg_min_primary
#   vpc_zone_identifier       = local.primary_subnets
#   health_check_type         = "ELB"
#   health_check_grace_period = 60
#   target_group_arns         = [aws_lb_target_group.primary.arn]
#   launch_template {
#     id      = aws_launch_template.primary.id
#     version = "$Latest"
#   }
#   tag {
#     key                 = "Name"
#     value               = "${var.project}-app-primary"
#     propagate_at_launch = true
#   }
# }

# # --- DR ---
# resource "aws_launch_template" "dr" {
#   provider      = aws.dr
#   name_prefix   = "${var.project}-lt-dr-"
#   image_id      = data.aws_ami.amzn2_dr.id
#   instance_type = local.cfg.instance_type
#   vpc_security_group_ids = [aws_security_group.app_dr_sg.id]
#   user_data     = base64encode(local.user_data)
#   tag_specifications {
#     resource_type = "instance"
#     tags          = merge(local.tags, { Role = "app-dr" })
#   }
# }

# resource "aws_lb" "dr" {
#   provider           = aws.dr
#   name               = "${var.project}-alb-dr-${local.rand}"
#   load_balancer_type = "application"
#   subnets            = local.dr_subnets
#   security_groups    = [aws_security_group.alb_dr_sg.id]
#   tags               = local.tags
# }

# resource "aws_lb_target_group" "dr" {
#   provider = aws.dr
#   name     = "${var.project}-tg-dr-${local.rand}"
#   port     = 5000
#   protocol = "HTTP"
#   vpc_id   = data.aws_vpc.dr.id
#   health_check {
#     path                = "/api/health"
#     matcher             = "200"
#     interval            = 15
#     healthy_threshold   = 2
#     unhealthy_threshold = 3
#     timeout             = 5
#   }
#   tags = local.tags
# }

# resource "aws_lb_listener" "dr_http" {
#   provider          = aws.dr
#   load_balancer_arn = aws_lb.dr.arn
#   port              = 80
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.dr.arn
#   }
# }

# resource "aws_autoscaling_group" "dr" {
#   provider                  = aws.dr
#   name                      = "${var.project}-asg-dr-${local.rand}"
#   min_size                  = local.cfg.asg_min_dr
#   max_size                  = local.cfg.asg_max_dr
#   desired_capacity          = local.cfg.asg_min_dr
#   vpc_zone_identifier       = local.dr_subnets
#   health_check_type         = "ELB"
#   health_check_grace_period = 60
#   target_group_arns         = [aws_lb_target_group.dr.arn]
#   launch_template {
#     id      = aws_launch_template.dr.id
#     version = "$Latest"
#   }
#   tag {
#     key                 = "Name"
#     value               = "${var.project}-app-dr"
#     propagate_at_launch = true
#   }
# }

# # ---------------------------------------------------------------------------
# # RDS MySQL: Primary + Cross-Region Read Replica (default subnets)
# # ---------------------------------------------------------------------------
# resource "aws_db_subnet_group" "primary" {
#   provider   = aws.primary
#   name       = "${var.project}-dbsubnet-primary-${local.rand}"
#   subnet_ids = local.primary_subnets
#   tags       = local.tags
# }

# resource "aws_db_instance" "primary" {
#   provider               = aws.primary
#   identifier             = "${var.project}-mysql-primary-${local.rand}"
#   engine                 = "mysql"
#   engine_version         = "8.0"
#   instance_class         = local.cfg.db_instance
#   allocated_storage      = local.cfg.db_alloc_gb
#   username               = local.cfg.db_username
#   password               = local.cfg.db_password
#   db_subnet_group_name   = aws_db_subnet_group.primary.name
#   vpc_security_group_ids = [aws_security_group.rds_primary_sg.id]
#   multi_az               = false
#   skip_final_snapshot    = true
#   backup_retention_period = 7
#   deletion_protection    = false
#   tags                   = local.tags
# }

# resource "aws_db_subnet_group" "dr" {
#   provider   = aws.dr
#   name       = "${var.project}-dbsubnet-dr-${local.rand}"
#   subnet_ids = local.dr_subnets
#   tags       = local.tags
# }

# resource "aws_db_instance" "dr_replica" {
#   provider                = aws.dr
#   identifier              = "${var.project}-mysql-dr-repl-${local.rand}"
#   engine                  = "mysql"
#   instance_class          = local.cfg.db_instance
#   allocated_storage       = local.cfg.db_alloc_gb
#   replicate_source_db     = aws_db_instance.primary.arn
#   db_subnet_group_name    = aws_db_subnet_group.dr.name
#   vpc_security_group_ids  = [aws_security_group.rds_dr_sg.id]
#   skip_final_snapshot     = true
#   backup_retention_period = 7
#   deletion_protection     = false
#   depends_on              = [aws_db_instance.primary]
#   tags                    = local.tags
# }

# # ---------------------------------------------------------------------------
# # S3 Frontend (Versioning + CRR) and CloudFront (OAC + Origin Failover)
# # ---------------------------------------------------------------------------
# resource "aws_s3_bucket" "web_primary" {
#   provider      = aws.primary
#   bucket        = "${var.project}-web-primary-${local.rand}"
#   force_destroy = true
#   tags          = local.tags
# }

# resource "aws_s3_bucket_versioning" "web_primary" {
#   provider = aws.primary
#   bucket   = aws_s3_bucket.web_primary.id
#   versioning_configuration { status = "Enabled" }
# }

# resource "aws_s3_bucket" "web_dr" {
#   provider      = aws.dr
#   bucket        = "${var.project}-web-dr-${local.rand}"
#   force_destroy = true
#   tags          = local.tags
# }

# resource "aws_s3_bucket_versioning" "web_dr" {
#   provider = aws.dr
#   bucket   = aws_s3_bucket.web_dr.id
#   versioning_configuration { status = "Enabled" }
# }

# # CRR (simple, SSE-S3)
# resource "aws_iam_role" "s3_repl" {
#   name = "${var.project}-s3repl-${local.rand}"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{ Effect = "Allow", Principal = { Service = "s3.amazonaws.com" }, Action = "sts:AssumeRole" }]
#   })
# }

# resource "aws_iam_role_policy" "s3_repl" {
#   role = aws_iam_role.s3_repl.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       { Effect = "Allow", Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"], Resource = [aws_s3_bucket.web_primary.arn] },
#       { Effect = "Allow", Action = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionForReplication", "s3:GetObjectVersionTagging"], Resource = ["${aws_s3_bucket.web_primary.arn}/*"] },
#       { Effect = "Allow", Action = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"], Resource = ["${aws_s3_bucket.web_dr.arn}/*"] }
#     ]
#   })
# }

# data "aws_caller_identity" "primary" { provider = aws.primary }

# data "aws_caller_identity" "dr" { provider = aws.dr }

# resource "aws_s3_bucket_replication_configuration" "web" {
#   provider   = aws.primary
#   role       = aws_iam_role.s3_repl.arn
#   bucket     = aws_s3_bucket.web_primary.id
#   depends_on = [aws_s3_bucket_versioning.web_primary, aws_s3_bucket_versioning.web_dr]

#   rule {
#     id     = "to-dr"
#     status = "Enabled"
#     filter { prefix = "" }
#     destination {
#       bucket                         = aws_s3_bucket.web_dr.arn
#       storage_class                  = "STANDARD"
#       access_control_translation { owner = "Destination" }
#       account                        = data.aws_caller_identity.dr.account_id
#       metrics { status = "Disabled" }
#     }
#     delete_marker_replication { status = "Enabled" }
#   }
# }

# # CloudFront OAC
# resource "aws_cloudfront_origin_access_control" "oac" {
#   name                              = "${var.project}-oac-${local.rand}"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }

# # Web Distribution (S3 Primary -> S3 DR via Origin Group)
# resource "aws_cloudfront_distribution" "web" {
#   enabled             = true
#   comment             = "${var.project} web failover"
#   default_root_object = "index.html"

#   origin_group {
#     origin_id = "web-og"
#     failover_criteria { status_codes = [500, 502, 503, 504] }
#     member { origin_id = "s3-primary" }
#     member { origin_id = "s3-dr" }
#   }

#   origin {
#     domain_name              = aws_s3_bucket.web_primary.bucket_regional_domain_name
#     origin_id                = "s3-primary"
#     origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
#   }

#   origin {
#     domain_name              = aws_s3_bucket.web_dr.bucket_regional_domain_name
#     origin_id                = "s3-dr"
#     origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
#   }

#   default_cache_behavior {
#     target_origin_id       = "web-og"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET", "HEAD"]
#     cached_methods         = ["GET", "HEAD"]
#     compress               = true
#     forwarded_values {
#       query_string = false
#       cookies {
#         forward = "none"
#       }
#     }
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
#   tags = local.tags
# }

# # Bucket policies to allow OAC (use SourceArn + SourceAccount)
# resource "aws_s3_bucket_policy" "web_primary" {
#   provider = aws.primary
#   bucket   = aws_s3_bucket.web_primary.id
#   policy   = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Sid = "AllowCFGetObjectOAC",
#       Effect = "Allow",
#       Principal = { Service = "cloudfront.amazonaws.com" },
#       Action = ["s3:GetObject"],
#       Resource = ["${aws_s3_bucket.web_primary.arn}/*"],
#       Condition = {
#         StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.web.arn, "AWS:SourceAccount" = data.aws_caller_identity.primary.account_id }
#       }
#     }]
#   })
# }

# resource "aws_s3_bucket_policy" "web_dr" {
#   provider = aws.dr
#   bucket   = aws_s3_bucket.web_dr.id
#   policy   = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Sid = "AllowCFGetObjectOAC",
#       Effect = "Allow",
#       Principal = { Service = "cloudfront.amazonaws.com" },
#       Action = ["s3:GetObject"],
#       Resource = ["${aws_s3_bucket.web_dr.arn}/*"],
#       Condition = {
#         StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.web.arn, "AWS:SourceAccount" = data.aws_caller_identity.primary.account_id }
#       }
#     }]
#   })
# }

# # API Distribution (ALB Primary -> ALB DR via Origin Group)
# resource "aws_cloudfront_distribution" "api" {
#   enabled = true
#   comment = "${var.project} API failover"

#   origin_group {
#     origin_id = "api-og"
#     failover_criteria { status_codes = [500, 502, 503, 504] }
#     member { origin_id = "alb-primary" }
#     member { origin_id = "alb-dr" }
#   }

#   origin {
#     domain_name = aws_lb.primary.dns_name
#     origin_id   = "alb-primary"
#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only" # ALBs listen on 80 in this setup
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#   }

#   origin {
#     domain_name = aws_lb.dr.dns_name
#     origin_id   = "alb-dr"
#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#   }

#   default_cache_behavior {
#     target_origin_id       = "api-og"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
#     cached_methods         = ["GET","HEAD","OPTIONS"]
#     compress               = true
#     forwarded_values {
#       query_string = true
#       cookies {
#         forward = "all"
#       }
#       headers = ["*"]
#     }
#     min_ttl = 0
#     default_ttl = 0
#     max_ttl = 0
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
#   tags = local.tags
# }

# # ---------------------------------------------------------------------------
# # Outputs
# # ---------------------------------------------------------------------------
# output "cloudfront_web_domain" {
#   value       = aws_cloudfront_distribution.web.domain_name
#   description = "Frontend URL"
# }
# output "cloudfront_api_domain" {
#   value       = aws_cloudfront_distribution.api.domain_name
#   description = "API base URL"
# }
# output "s3_primary_bucket" {
#   value       = aws_s3_bucket.web_primary.bucket
#   description = "Upload frontend here"
# }
# output "primary_alb_dns" {
#   value       = aws_lb.primary.dns_name
#   description = "Primary ALB DNS"
# }
# output "dr_alb_dns" {
#   value       = aws_lb.dr.dns_name
#   description = "DR ALB DNS"
# }



