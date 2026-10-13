# ==============================================================================
# Terraform Variables: KopDes Merah Putih - AWS Native Infrastructure
# ==============================================================================

variable "aws_region" {
  description = "AWS Region target tempat infrastruktur KopDes di-deploy"
  type        = string
  default     = "us-east-1" # US East (N. Virginia)
}

variable "project_name" {
  description = "Nama prefix resource proyek KopDes"
  type        = string
  default     = "kopdes"
}

variable "environment" {
  description = "Nama environment (misal: production, staging, lab)"
  type        = string
  default     = "production"
}

# ------------------------------------------------------------------------------
# Networking (VPC & Subnets Multi-AZ)
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Blok CIDR untuk Virtual Private Cloud (VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Daftar CIDR untuk Public Subnet (Application Load Balancer) pada 2 AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Daftar CIDR untuk Private Application Subnet (EC2 Auto Scaling Group) pada 2 AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Daftar CIDR untuk Private Database Subnet (Amazon RDS) pada 2 AZ"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "single_nat_gateway" {
  description = "Gunakan 1 NAT Gateway untuk efisiensi biaya lab/studi. Set false untuk Multi-AZ NAT Gateway redundan di production."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Compute & Auto Scaling Group (EC2 Web Server Tier)
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "Tipe instance EC2 untuk node web server KopDes"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Kapasitas minimum instance pada Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Kapasitas maksimum instance pada Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Kapasitas awal (desired) instance pada Auto Scaling Group"
  type        = number
  default     = 2
}

variable "git_repo_url" {
  description = "URL git repository aplikasi KopDes Web Application untuk proses self-bootstrap instance"
  type        = string
  default     = "https://github.com/fendyramadhani9-cloud/kopdes-iac-automationAWS.git"
}

variable "iac_repo_url" {
  description = "URL git repository IaC Automation (Terraform & Ansible) untuk di-clone oleh EC2 saat bootstrap"
  type        = string
  default     = "https://github.com/fendyramadhani9-cloud/terraform-automated-lab.git"
}

# ------------------------------------------------------------------------------
# Database Tier (Amazon RDS MySQL Compatible)
# ------------------------------------------------------------------------------
variable "db_instance_class" {
  description = "Tipe instance Amazon RDS (MySQL compatible)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Alokasi disk storage database (GB, gp3)"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Aktifkan Multi-AZ untuk failover otomatis RDS. Default false untuk mengendalikan biaya lab."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Nama database awal yang dibuat di RDS"
  type        = string
  default     = "kopdes"
}

variable "db_username" {
  description = "Master username administrator database RDS"
  type        = string
  default     = "kopdes_admin"
}

variable "db_password" {
  description = "Master password database RDS. Jika null, Terraform akan meng-generate password acak yang aman dan menyimpannya di AWS Secrets Manager."
  type        = string
  default     = null
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Amazon Simple Email Service (SES) & Opsional Storage
# ------------------------------------------------------------------------------
variable "ses_sender_email" {
  description = "Alamat email pengirim laporan rekapitulasi KopDes di Amazon SES (Wajib diverifikasi di SES Console)"
  type        = string
  default     = "noreply@kopdes.id"
}

variable "ses_recipient_email" {
  description = "Alamat email penerima laporan rekapitulasi ekonomi"
  type        = string
  default     = "admin@kopdes.id"
}

variable "ses_enabled" {
  description = "Aktifkan pengiriman email otomatis via Amazon SES"
  type        = bool
  default     = true
}

variable "enable_s3_storage" {
  description = "Buat S3 bucket jika aplikasi membutuhkan penyimpanan berkas persisten di masa depan. Default false untuk efisiensi biaya."
  type        = bool
  default     = false
}
