terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.9.0"
    }
     random = {
      source = "hashicorp/random"
      version = "3.7.2"
    }
     archive = {
      source = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}


########################################
# Variables
########################################
variable "project" {
  type    = string
  default = "todo3tier"
}
variable "primary_region" {
  type    = string
  default = "ap-south-1"
} # Mumbai
variable "dr_region" {
  type    = string
  default = "ap-southeast-1"
} # Singapore

# App/EC2
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# RDS sizing
variable "db_instance" {
  type    = string
  default = "db.t3.micro"
}
variable "db_alloc_gb" {
  type    = number
  default = 20
}
variable "db_username" {
  type    = string
  default = "appuser"
}
variable "db_password" {
  type    = string
  default = "ChangeMe!123"
}

# DR watchdog tuning
variable "watch_interval_minutes" {
  type    = number
  default = 1
}
variable "min_consecutive_failures" {
  type    = number
  default = 3
}

locals {
  ws   = terraform.workspace
  tags = { Project = var.project, Workspace = local.ws }

  # SSM parameters (single source of truth for app)
  ssm_db_username = "/${var.project}/${local.ws}/db_username"
  ssm_db_password = "/${var.project}/${local.ws}/db_password"
  ssm_db_name     = "/${var.project}/${local.ws}/db_name"
  ssm_db_url      = "/${var.project}/${local.ws}/database_url"

  # helper for names
  name = "${var.project}-${local.ws}"
}

########################################
# Providers & identities
########################################
provider "aws" { region = var.primary_region }
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}
provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

data "aws_caller_identity" "primary" { provider = aws.primary }
data "aws_caller_identity" "dr"      { provider = aws.dr }

########################################
# Default VPC + 2 subnets (each region)
########################################
data "aws_vpc" "primary" {
  provider = aws.primary
  default  = true
}
data "aws_vpc" "dr" {
  provider = aws.dr
  default  = true
}

data "aws_subnets" "primary_default" {
  provider = aws.primary
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}
data "aws_subnets" "dr_default" {
  provider = aws.dr
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.dr.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  primary_subnets = slice(data.aws_subnets.primary_default.ids, 0, 2)
  dr_subnets      = slice(data.aws_subnets.dr_default.ids, 0, 2)
}

########################################
# Security Groups
########################################
# ALB -> Internet (80)
resource "aws_security_group" "alb" {
  provider = aws.primary
  name     = "${local.name}-alb-sg"
  vpc_id   = data.aws_vpc.primary.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

# EC2 -> only from ALB on 5000 (+ optional SSH for demo)
resource "aws_security_group" "ec2" {
  provider = aws.primary
  name     = "${local.name}-ec2-sg"
  vpc_id   = data.aws_vpc.primary.id
  ingress {
    description     = "from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # tighten in prod
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

# RDS -> only from EC2 SG
resource "aws_security_group" "rds_primary" {
  provider = aws.primary
  name     = "${local.name}-rds-primary-sg"
  vpc_id   = data.aws_vpc.primary.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}
resource "aws_security_group" "rds_dr" {
  provider = aws.dr
  name     = "${local.name}-rds-dr-sg"
  vpc_id   = data.aws_vpc.dr.id
  # no EC2 in DR; open for admin/bastion or VPC-only (demo: allow all VPC)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # restrict in prod
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

# DR Security Groups
resource "aws_security_group" "alb_dr" {
  provider = aws.dr
  name     = "${local.name}-alb-dr-sg"
  vpc_id   = data.aws_vpc.dr.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}
resource "aws_security_group" "ec2_dr" {
  provider = aws.dr
  name     = "${local.name}-ec2-dr-sg"
  vpc_id   = data.aws_vpc.dr.id
  ingress {
    description     = "from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_dr.id]
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
  tags = local.tags
}

########################################
# AMI (Amazon Linux 2)
########################################
data "aws_ami" "amzn2_primary" {
  provider    = aws.primary
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "amzn2_dr" {
  provider    = aws.dr
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


########################################
# IAM for EC2: read SSM params
########################################
resource "aws_iam_role" "ec2_role" {
  name = "${local.name}-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]
  })
  tags = local.tags
}
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_policy" "ec2_get_params" {
  name = "${local.name}-ec2-get-params"
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[{
      Effect="Allow",
      Action=["ssm:GetParameter","ssm:GetParameters","ssm:GetParameterHistory"],
      Resource=[
        "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_username}",
        "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_password}",
        "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_name}",
        "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_url}"
      ]
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_attach_get_params" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_get_params.arn
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name}-ec2-ip"
  role = aws_iam_role.ec2_role.name
}

########################################
# EC2 Instances (primary & DR)
########################################
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -xe

    # Update system and install dependencies
    yum update -y
    yum install -y git python3 python3-pip python3-virtualenv jq awscli

    # Clone your app
    cd /opt
    git clone https://github.com/the-shreyashmaurya/todo-3tier-f13.git || true
    cd /opt/todo-3tier-f13/backend

    # Create and activate virtualenv
    python3 -m venv /opt/todo-venv

    # Install requirements
    if [ -f requirements.txt ]; then
      /opt/todo-venv/bin/pip install -r requirements.txt
    else
      /opt/todo-venv/bin/pip install flask flask_sqlalchemy flask_cors pymysql gunicorn
    fi

    # Create SSM refresh helper
    cat > /usr/local/bin/refresh_db_env.sh <<'EOF'
    #!/bin/bash
    PARAM_NAME="${local.ssm_db_url}"
    DEST="/etc/todo.env"
    DB_URL=$(/usr/bin/aws ssm get-parameter --name "$PARAM_NAME" --with-decryption --region ${var.primary_region} --query "Parameter.Value" --output text 2>/dev/null || echo "")
    [ -z "$DB_URL" ] && exit 0
    NEW_LINE="DATABASE_URL=$DB_URL"
    if [ ! -f "$DEST" ] || [ "$(cat $DEST)" != "$NEW_LINE" ]; then
      echo "$NEW_LINE" > $DEST
      chmod 640 $DEST
      chown root:root $DEST
      systemctl restart todo-backend || true
    fi
    EOF
    chmod +x /usr/local/bin/refresh_db_env.sh
    /usr/local/bin/refresh_db_env.sh || true

    # Create systemd service
    cat > /etc/systemd/system/todo-backend.service <<'EOF'
    [Unit]
    Description=Todo Backend Flask App
    After=network.target

    [Service]
    User=root
    WorkingDirectory=/opt/todo-3tier-f13/backend
    EnvironmentFile=/etc/todo.env
    Environment="PATH=/opt/todo-venv/bin"
    ExecStart=/opt/todo-venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    EOF

    # Reload systemd and start service
    systemctl daemon-reload
    systemctl enable todo-backend
    systemctl start todo-backend

    # Add cron job to refresh SSM every minute
    (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/refresh_db_env.sh >/tmp/refresh_db_env.log 2>&1") | crontab -
  EOT
}

resource "aws_instance" "app" {
  provider                    = aws.primary
  ami                         = data.aws_ami.amzn2_primary.id
  instance_type               = var.instance_type
  subnet_id                   = local.primary_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.user_data)
  tags                        = merge(local.tags, { Name = "${local.name}-app-ec2" })
}

resource "aws_instance" "app_dr" {
  provider                    = aws.dr
  ami                         = data.aws_ami.amzn2_dr.id
  instance_type               = var.instance_type
  subnet_id                   = local.dr_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_dr.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.user_data)
  # Do not start the instance automatically. It will be started by the Lambda watchdog.
  # This saves cost by not running the instance in DR unless needed.
  instance_initiated_shutdown_behavior = "stop"
  tags                        = merge(local.tags, { Name = "${local.name}-app-ec2-dr" })
}

########################################
# ALB (primary) in front of EC2
########################################
resource "aws_lb" "app" {
  provider           = aws.primary
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  subnets            = local.primary_subnets
  security_groups    = [aws_security_group.alb.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "app" {
  provider = aws.primary
  name     = "${local.name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.primary.id
  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = local.tags
}

resource "aws_lb_target_group_attachment" "app" {
  provider         = aws.primary
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 5000
}

resource "aws_lb_listener" "http" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type               = "forward"
    target_group_arn   = aws_lb_target_group.app.arn
  }
}

# DR ALB (initially stopped)
resource "aws_lb" "app_dr" {
  provider           = aws.dr
  name               = "${local.name}-dr-alb"
  load_balancer_type = "application"
  subnets            = local.dr_subnets
  security_groups    = [aws_security_group.alb_dr.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "app_dr" {
  provider = aws.dr
  name     = "${local.name}-dr-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.dr.id
  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = local.tags
}

resource "aws_lb_target_group_attachment" "app_dr" {
  provider         = aws.dr
  target_group_arn = aws_lb_target_group.app_dr.arn
  target_id        = aws_instance.app_dr.id
  port             = 5000
}

resource "aws_lb_listener" "http_dr" {
  provider          = aws.dr
  load_balancer_arn = aws_lb.app_dr.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type               = "forward"
    target_group_arn   = aws_lb_target_group.app_dr.arn
  }
}

########################################
# RDS: Primary + cross-region read-replica
########################################
resource "aws_db_subnet_group" "primary" {
  provider   = aws.primary
  name       = "${local.name}-dbsubnet-primary"
  subnet_ids = local.primary_subnets
  tags       = local.tags
}
resource "aws_db_subnet_group" "dr" {
  provider   = aws.dr
  name       = "${local.name}-dbsubnet-dr"
  subnet_ids = local.dr_subnets
  tags       = local.tags
}

resource "aws_db_instance" "primary" {
  provider               = aws.primary
  identifier             = "${local.name}-mysql-primary"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance
  allocated_storage      = var.db_alloc_gb
  username               = var.db_username
  password               = var.db_password
  db_name                = "todo_db"
  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds_primary.id]
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false
  backup_retention_period = 7
  tags = local.tags
}

resource "aws_db_instance" "dr_replica" {
  provider               = aws.dr
  identifier             = "${local.name}-mysql-dr-replica"
  engine                 = "mysql"
  instance_class         = var.db_instance
  replicate_source_db    = aws_db_instance.primary.arn
  db_subnet_group_name   = aws_db_subnet_group.dr.name
  vpc_security_group_ids = [aws_security_group.rds_dr.id]
  skip_final_snapshot    = true
  deletion_protection    = false
  depends_on             = [aws_db_instance.primary]
  tags = local.tags
}

########################################
# SSM parameters (initially point to PRIMARY DB)
########################################
resource "aws_ssm_parameter" "db_username" {
  name  = local.ssm_db_username
  type  = "String"
  value = var.db_username
  tags  = local.tags
}
resource "aws_ssm_parameter" "db_password" {
  name  = local.ssm_db_password
  type  = "SecureString"
  value = var.db_password
  tags  = local.tags
}
resource "aws_ssm_parameter" "db_name" {
  name  = local.ssm_db_name
  type  = "String"
  value = "todo_db"
  tags  = local.tags
}

resource "aws_ssm_parameter" "database_url" {
  name       = local.ssm_db_url
  type       = "SecureString"
  value      = "mysql+pymysql://${var.db_username}:${var.db_password}@${aws_db_instance.primary.address}:3306/todo_db"
  depends_on = [aws_db_instance.primary]
  tags       = local.tags
}

########################################
# Lambda watchdog: promote DR + update SSM on failure
########################################
resource "aws_iam_role" "lambda_role" {
  name = "${local.name}-lambda-rds-dr-promote"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]
  })
  tags = local.tags
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.name}-lambda-rds-dr-promote-policy"
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[
      { Effect="Allow", Action=["rds:DescribeDBInstances","rds:PromoteReadReplica"], Resource="*" },
      { Effect="Allow", Action=["ec2:StartInstances"], Resource=[
          aws_instance.app_dr.arn
      ]},
      { Effect="Allow", Action=["ec2:DescribeInstances"], Resource="*" },
      { Effect="Allow", Action=["elasticloadbalancing:DescribeLoadBalancers"], Resource="*" },
      { Effect="Allow", Action=["elasticloadbalancing:StartLoadBalancer"], Resource=[
          aws_lb.app_dr.arn
      ]},
      { Effect="Allow", Action=["cloudfront:UpdateDistribution"], Resource=[
          aws_cloudfront_distribution.cf.arn
      ]},
      { Effect="Allow", Action=["ssm:GetParameter","ssm:PutParameter"], Resource=[
          "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_url}",
          "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_username}",
          "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_password}",
          "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter${local.ssm_db_name}",
          "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.primary.account_id}:parameter/${var.project}/${local.ws}/_dr_watch/fail_count"
      ]},
      { Effect="Allow", Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource="arn:aws:logs:*:*:*" }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_dr_watch.zip"
  source {
    filename = "lambda_main.py"
    content  = <<-PY
      import os, json, boto3, botocore, time
      
      PRIMARY_REGION  = os.environ["PRIMARY_REGION"]
      DR_REGION       = os.environ["DR_REGION"]
      PRIMARY_DB_ID   = os.environ["PRIMARY_DB_ID"]
      DR_DB_ID        = os.environ["DR_DB_ID"]
      DR_EC2_ID       = os.environ["DR_EC2_ID"]
      DR_ALB_ARN      = os.environ["DR_ALB_ARN"]
      CF_DISTRO_ID    = os.environ["CF_DISTRO_ID"]
      SSM_DB_URL      = os.environ["SSM_DB_URL"]
      SSM_USER        = os.environ["SSM_USER"]
      SSM_PASS        = os.environ["SSM_PASS"]
      SSM_NAME        = os.environ["SSM_NAME"]
      SSM_FAIL_COUNT  = os.environ["SSM_FAIL_COUNT_PARAM"]
      MIN_CONSEC      = int(os.environ["MIN_CONSECUTIVE_FAILURES"])

      rds_primary = boto3.client("rds", region_name=PRIMARY_REGION)
      rds_dr      = boto3.client("rds", region_name=DR_REGION)
      ec2_dr      = boto3.client("ec2", region_name=DR_REGION)
      elb_dr      = boto3.client("elb", region_name=DR_REGION)
      ssm         = boto3.client("ssm", region_name=PRIMARY_REGION)
      cf          = boto3.client("cloudfront", region_name="us-east-1") # CloudFront is global

      def get_param(name, decrypt=True, default=None):
          try:
              resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
              return resp["Parameter"]["Value"]
          except ssm.exceptions.ParameterNotFound:
              return default

      def put_param(name, value, typ="SecureString"):
          ssm.put_parameter(Name=name, Value=value, Type=typ, Overwrite=True)

      def inc_fail():
          c = int(get_param(SSM_FAIL_COUNT, decrypt=False, default="0") or "0")
          c += 1
          put_param(SSM_FAIL_COUNT, str(c), typ="String")
          return c

      def reset_fail():
          put_param(SSM_FAIL_COUNT, "0", typ="String")

      def primary_healthy():
          try:
              resp = rds_primary.describe_db_instances(DBInstanceIdentifier=PRIMARY_DB_ID)
              status = resp["DBInstances"][0].get("DBInstanceStatus","unknown")
              return status == "available"
          except botocore.exceptions.ClientError:
              return False
          except Exception:
              return False

      def promote_dr():
          rds_dr.promote_read_replica(DBInstanceIdentifier=DR_DB_ID)
          waiter = rds_dr.get_waiter("db_instance_available")
          waiter.wait(DBInstanceIdentifier=DR_DB_ID)

      def dr_endpoint():
          resp = rds_dr.describe_db_instances(DBInstanceIdentifier=DR_DB_ID)
          ep  = resp["DBInstances"][0]["Endpoint"]
          return ep["Address"], ep["Port"]
      
      def start_dr_services():
          # Start EC2 instance
          ec2_dr.start_instances(InstanceIds=[DR_EC2_ID])
          waiter = ec2_dr.get_waiter("instance_running")
          waiter.wait(InstanceIds=[DR_EC2_ID])
          # Start ALB (it's always "on" but we need to wait for it to be ready)
          # No specific start/stop for ALB, we just wait for it to be available.
          waiter = elb_dr.get_waiter("load_balancer_exists")
          waiter.wait(LoadBalancerArns=[DR_ALB_ARN])

      def update_cloudfront_to_dr():
          resp = cf.get_distribution_config(Id=CF_DISTRO_ID)
          config = resp["DistributionConfig"]
          etag = resp["ETag"]
          
          # Change the default origin to the DR ALB origin
          config["DefaultCacheBehavior"]["TargetOriginId"] = "dr-alb-origin"
          
          cf.update_distribution(
              DistributionConfig=config,
              Id=CF_DISTRO_ID,
              IfMatch=etag
          )

      def lambda_handler(event, context):
          if primary_healthy():
              reset_fail()
              return {"statusCode":200, "body":json.dumps({"ok":True,"action":"primary_ok"})}

          fails = inc_fail()
          if fails < MIN_CONSEC:
              return {"statusCode":200, "body":json.dumps({"ok":False,"action":"wait","fails":fails})}

          try:
              promote_dr()
              start_dr_services()
              update_cloudfront_to_dr()
              reset_fail()
          except Exception as e:
              return {"statusCode":500, "body":json.dumps({"ok":False,"error":str(e)})}

          try:
              user = get_param(SSM_USER, decrypt=False)
              pwd  = get_param(SSM_PASS, decrypt=True)
              name = get_param(SSM_NAME, decrypt=False)
              host, port = dr_endpoint()
              url = f"mysql+pymysql://{user}:{pwd}@{host}:{port}/{name}"
              put_param(SSM_DB_URL, url, typ="SecureString")
              return {"statusCode":200, "body":json.dumps({"ok":True,"action":"promoted","new_url":url})}
          except Exception as e:
              return {"statusCode":500, "body":json.dumps({"ok":False,"error":str(e)})}
    PY
  }
}

resource "aws_lambda_function" "dr_watch" {
  function_name = "${local.name}-rds-dr-watch"
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "lambda_main.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.10"
  timeout       = 300
  publish       = true
  environment {
    variables = {
      PRIMARY_REGION             = var.primary_region
      DR_REGION                  = var.dr_region
      PRIMARY_DB_ID              = aws_db_instance.primary.id
      DR_DB_ID                   = aws_db_instance.dr_replica.id
      DR_EC2_ID                  = aws_instance.app_dr.id
      DR_ALB_ARN                 = aws_lb.app_dr.arn
      CF_DISTRO_ID               = aws_cloudfront_distribution.cf.id
      SSM_DB_URL                 = local.ssm_db_url
      SSM_USER                   = local.ssm_db_username
      SSM_PASS                   = local.ssm_db_password
      SSM_NAME                   = local.ssm_db_name
      SSM_FAIL_COUNT_PARAM       = "/${var.project}/${local.ws}/_dr_watch/fail_count"
      MIN_CONSECUTIVE_FAILURES   = tostring(var.min_consecutive_failures)
    }
  }
  depends_on = [aws_db_instance.primary, aws_db_instance.dr_replica, aws_iam_role_policy_attachment.lambda_attach, aws_instance.app_dr, aws_lb.app_dr]
  tags       = local.tags
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr_watch.arn
  principal     = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${local.name}-dr-watch-schedule"
  schedule_expression = "rate(${var.watch_interval_minutes} minute${var.watch_interval_minutes == 1 ? "" : "s"})"
  tags = local.tags
}
resource "aws_cloudwatch_event_target" "schedule_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "dr-watch"
  arn       = aws_lambda_function.dr_watch.arn
}

########################################
# S3 (static DR) + CloudFront OAC
########################################
resource "aws_s3_bucket" "static" {
  provider      = aws.primary
  bucket        = "${local.name}-static-${random_string.rand.result}"
  force_destroy = true
  tags          = local.tags
}
resource "aws_s3_bucket_versioning" "static" {
  provider = aws.primary
  bucket   = aws_s3_bucket.static.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "static" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "static_dr" {
  provider      = aws.dr
  bucket        = "${local.name}-dr-static-${random_string.rand.result}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "static_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.static_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "static_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.static_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "rand" {
  length  = 6
  upper   = false
  special = false
}

# CloudFront OAC (modern replacement for OAI)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_origin_access_control" "oac_dr" {
  provider = aws.dr
  name                              = "${local.name}-oac-dr"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
# Upload index.html to DR S3 bucket
resource "aws_s3_object" "dr_index_html" {
  provider = aws.dr
  bucket   = aws_s3_bucket.static_dr.id
  key      = "index.html"
  content_type = "text/html"
  content = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>DR Region Active</title>
        <style>
            body { font-family: sans-serif; text-align: center; padding-top: 100px; }
            h1 { color: #d9534f; }
            p { font-size: 1.2em; }
        </style>
    </head>
    <body>
        <h1>Disaster Recovery Region is now Active.</h1>
        <p>The primary region is currently unavailable. We are serving content from our disaster recovery site.</p>
        <p>Your data is safe and the application will be back to normal shortly.</p>
    </body>
    </html>
  HTML
  acl = "public-read" # ACL is required for website hosting, OAC is for CF origin access
}

########################################
# CloudFront: Origin Group (ALB primary -> ALB DR -> S3 failover)
########################################
resource "aws_cloudfront_distribution" "cf" {
  enabled             = true
  comment             = "${local.name} - CF failover ALB->ALB DR"
  default_root_object = "index.html"

  # Origin Group for failover
  origin_group {
    origin_id = "og-app"
    failover_criteria { status_codes = [500, 502, 503, 504] }
    member { origin_id = "alb-primary" }
    member { origin_id = "alb-dr" } # New DR origin
  }

  # Primary origin: ALB
  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "alb-primary"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Secondary origin: S3 (private via OAC)
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }
  
  # DR Origin: DR ALB
  origin {
    domain_name = aws_lb.app_dr.dns_name
    origin_id   = "alb-dr"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  # Default behavior: route to origin group (dynamic/no cache)
  default_cache_behavior {
    target_origin_id       = "og-app"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET","HEAD","OPTIONS"]
    cached_methods         = ["GET","HEAD","OPTIONS"]
    compress               = true
    forwarded_values {
      query_string = true
      cookies { forward = "all" }
      # headers = ["*"] # Not allowed for S3 origin, removed for compliance
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = local.tags
}
# Allow CloudFront to read from S3 via OAC (bucket policy ties to CF distribution ARN)
resource "aws_s3_bucket_policy" "static" {
  provider = aws.primary
  bucket   = aws_s3_bucket.static.id
  policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid = "AllowCFGetObjectOAC",
      Effect = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action = ["s3:GetObject"],
      Resource = ["${aws_s3_bucket.static.arn}/*"],
      Condition = {
        StringEquals = {
          "AWS:SourceArn"    = aws_cloudfront_distribution.cf.arn,
          "AWS:SourceAccount"= data.aws_caller_identity.primary.account_id
        }
      }
    }]
  })
}

########################################
# Outputs
########################################

output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}
output "alb_dns" {
  value = aws_lb.app.dns_name
}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cf.domain_name
}
output "rds_primary_endpoint" {
  value = aws_db_instance.primary.address
}
output "rds_dr_identifier" {
  value = aws_db_instance.dr_replica.id
}
output "ssm_database_url_param" {
  value = local.ssm_db_url
}
output "api_endpoint" {
  description = "Direct API endpoint (ALB DNS)"
  value       = "http://${aws_lb.app.dns_name}/api"
}
output "s3_static_endpoint" {
  description = "Direct S3 static bucket endpoint"
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}
