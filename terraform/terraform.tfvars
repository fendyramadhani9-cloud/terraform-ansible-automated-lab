# ==============================================================================
# KopDes Merah Putih - AWS Native Infrastructure Variables
# ==============================================================================

aws_region   = "us-east-1"
project_name = "kopdes"
environment  = "production"

# Network
vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
single_nat_gateway       = true

# Compute (Auto Scaling Group)
instance_type        = "t3.micro"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

# Database (Amazon RDS MySQL)
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_multi_az          = false
db_name              = "kopdes"
db_username          = "kopdes_admin"

# Amazon SES
ses_sender_email    = "noreply@kopdes.id"
ses_recipient_email = "admin@kopdes.id"
ses_enabled         = true

# S3
enable_s3_storage = false

# Git Repositories
git_repo_url = "https://github.com/fendyramadhani9-cloud/kopdes-iac-automationAWS.git"
iac_repo_url = "https://github.com/fendyramadhani9-cloud/terraform-automated-lab.git"
