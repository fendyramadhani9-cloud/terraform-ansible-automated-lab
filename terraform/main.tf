# ==============================================================================
# KopDes Merah Putih - AWS Native Infrastructure
# Terraform Configuration: VPC, Multi-AZ Subnets, ALB, ASG, RDS, IAM
# ==============================================================================

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ------------------------------------------------------------------------------
# Local Variables
# ------------------------------------------------------------------------------
locals {
  azs               = slice(data.aws_availability_zones.available.names, 0, 2)
  db_password_final = var.db_password != null ? var.db_password : random_password.rds_password[0].result
  sns_recipient     = var.sns_recipient_email != "" ? var.sns_recipient_email : var.ses_recipient_email
}

# Generate random secure password jika password tidak diisi secara eksplisit
resource "random_password" "rds_password" {
  count   = var.db_password == null ? 1 : 0
  length  = 24
  special = false
}

# ------------------------------------------------------------------------------
# Amazon VPC & Networking (Multi-AZ)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (ALB Entry Point)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "Public"
  }
}

# Private Application Subnets (EC2 Auto Scaling Group)
resource "aws_subnet" "private_app" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-app-subnet-${count.index + 1}"
    Tier = "PrivateApp"
  }
}

# Private Database Subnets (Amazon RDS)
resource "aws_subnet" "private_db" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-db-subnet-${count.index + 1}"
    Tier = "PrivateDB"
  }
}

# Elastic IP & NAT Gateway untuk Akses Internet Keluar dari Private Subnet (Paket OS, SES, Git)
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : 2
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_db" {
  count  = 2
  vpc_id = aws_vpc.main.id

  # Subnet database privat terisolasi penuh tanpa default route ke NAT Gateway

  tags = {
    Name = "${var.project_name}-private-db-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

# ------------------------------------------------------------------------------
# Security Groups (Prinsip Least Privilege)
# ------------------------------------------------------------------------------

# 1. Security Group untuk Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Izinkan akses HTTP/HTTPS publik ke Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publik dari Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress ke Target Group EC2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# 2. Security Group untuk EC2 Auto Scaling Group
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Izinkan trafik hanya dari ALB ke EC2 Web Server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Trafik HTTP hanya dari ALB Security Group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Akses keluar ke internet via NAT Gateway (OS update, SES, Git)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# 3. Security Group untuk Amazon RDS (Prinsip Least Privilege - Tanpa Egress)
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Izinkan koneksi MySQL/MariaDB port 3306 HANYA dari EC2 App Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL port 3306 dari EC2 Web Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  # Egress dihilangkan: RDS stateful, respon query diizinkan otomatis tanpa egress out-bound.

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ------------------------------------------------------------------------------
# Secrets Manager & Amazon RDS Database
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "Kredensial database Amazon RDS untuk aplikasi KopDes"
  recovery_window_in_days = 0 # Lab cleanup immediate purge

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.rds.address
    port     = 3306
    dbname   = var.db_name
    username = var.db_username
    password = local.db_password_final
  })
}

resource "aws_db_subnet_group" "rds_subnets" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group private untuk RDS KopDes Multi-AZ"
  subnet_ids  = aws_subnet.private_db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "rds" {
  identifier            = "${var.project_name}-database"
  engine                = "mysql"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true
  publicly_accessible   = false

  db_name  = var.db_name
  username = var.db_username
  password = local.db_password_final

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  backup_retention_period     = 7
  skip_final_snapshot         = true
  deletion_protection         = false
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = true

  tags = {
    Name = "${var.project_name}-rds-mysql"
  }
}

# ------------------------------------------------------------------------------
# IAM Role & Instance Profile untuk EC2 (Least Privilege / AWS Academy Mode)
# Di AWS Academy: Menggunakan LabInstanceProfile bawaan tanpa membuat IAM role baru
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  count = var.use_aws_academy ? 0 : 1
  name  = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-iam-role"
  }
}

# Kebijakan izin Amazon SNS dan Secrets Manager
resource "aws_iam_policy" "ec2_policy" {
  count       = var.use_aws_academy ? 0 : 1
  name        = "${var.project_name}-ec2-least-privilege-policy"
  description = "Izin least privilege untuk SNS publish laporan dan Secrets Manager read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Amazon SNS: Pengiriman email laporan rekapitulasi via Topik SNS
      {
        Sid    = "AllowSnsPublishReport"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.reports.arn
      },
      # 2. AWS Secrets Manager: Baca kredensial DB
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_custom_attach" {
  count      = var.use_aws_academy ? 0 : 1
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = aws_iam_policy.ec2_policy[0].arn
}

# Amazon SSM Managed Instance Core: Memungkinkan akses console/terminal via AWS Systems Manager
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  count      = var.use_aws_academy ? 0 : 1
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.use_aws_academy ? 0 : 1
  name  = "${var.project_name}-ec2-instance-profile"
  role  = aws_iam_role.ec2_role[0].name
}

# ------------------------------------------------------------------------------
# Opsional S3 Storage (Jika Diaktifkan)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "app_storage" {
  count         = var.enable_s3_storage ? 1 : 0
  bucket        = "${var.project_name}-storage-${var.environment}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-storage-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  count                   = var.enable_s3_storage ? 1 : 0
  bucket                  = aws_s3_bucket.app_storage[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Amazon SNS Topic (Email Notification Support untuk AWS Academy & SES Fallback)
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "reports" {
  name = "${var.project_name}-economic-reports-topic"

  tags = {
    Name = "${var.project_name}-sns-reports"
  }
}

resource "aws_sns_topic_subscription" "email_sub" {
  count     = local.sns_recipient != "" ? 1 : 0
  topic_arn = aws_sns_topic.reports.arn
  protocol  = "email"
  endpoint  = local.sns_recipient
}


# ------------------------------------------------------------------------------
# Application Load Balancer (ALB)
# ------------------------------------------------------------------------------
resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name                 = "${var.project_name}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 30

  # Sticky Session: Menjamin konsistensi sesi login pengguna antar instance EC2
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    enabled             = true
    path                = "/index.php?page=login"
    protocol            = "HTTP"
    matcher             = "200,302"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

# ------------------------------------------------------------------------------
# Launch Template & Auto Scaling Group (EC2)
# ------------------------------------------------------------------------------
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = var.use_aws_academy ? var.academy_instance_profile_name : aws_iam_instance_profile.ec2_profile[0].name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # IMDSv2 Enforced untuk keamanan metadata instance
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Self-bootstrapping Ansible Cloud-Init script
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    git_repo_url   = var.git_repo_url
    iac_repo_url   = var.iac_repo_url
    db_host        = aws_db_instance.rds.address
    db_name        = var.db_name
    db_user        = var.db_username
    db_secret_name = aws_secretsmanager_secret.db_credentials.name
    aws_region     = var.aws_region
    alb_dns        = aws_lb.alb.dns_name
    sns_recipient  = local.sns_recipient
    sns_topic_arn  = aws_sns_topic.reports.arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-webserver"
      Project     = var.project_name
      Environment = var.environment
      Role        = "webserver"
      Tier        = "Application"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "${var.project_name}-asg-"
  vpc_zone_identifier = aws_subnet.private_app[*].id
  target_group_arns   = [aws_lb_target_group.alb_tg.arn]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300
  force_delete              = true

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-webserver"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "webserver"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ------------------------------------------------------------------------------
# Auto Scaling Policy: Target-Tracking CPU Utilization (70%)
# ------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "${var.project_name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
