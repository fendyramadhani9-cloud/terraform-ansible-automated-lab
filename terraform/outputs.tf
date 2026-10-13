# ==============================================================================
# Terraform Outputs: KopDes Merah Putih - AWS Native Infrastructure
# Menampilkan endpoint akses dan detail infrastruktur tanpa membocorkan rahasia
# ==============================================================================

output "alb_dns_name" {
  description = "Domain DNS Application Load Balancer (Gunakan URL ini di browser untuk mengakses KopDes)"
  value       = "http://${aws_lb.alb.dns_name}"
}

output "alb_arn" {
  description = "ARN dari Application Load Balancer"
  value       = aws_lb.alb.arn
}

output "vpc_id" {
  description = "ID dari Amazon Virtual Private Cloud (VPC)"
  value       = aws_vpc.main.id
}

output "asg_name" {
  description = "Nama Auto Scaling Group untuk web server KopDes"
  value       = aws_autoscaling_group.app_asg.name
}

output "rds_endpoint" {
  description = "Endpoint koneksi Amazon RDS MySQL (hanya dapat diakses dari private subnet EC2)"
  value       = aws_db_instance.rds.endpoint
}

output "rds_database_name" {
  description = "Nama database yang aktif di Amazon RDS"
  value       = aws_db_instance.rds.db_name
}

output "secrets_manager_secret_arn" {
  description = "ARN AWS Secrets Manager yang menyimpan kredensial database secara aman"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "s3_bucket_name" {
  description = "Nama S3 Bucket penyimpanan (jika diaktifkan)"
  value       = var.enable_s3_storage ? aws_s3_bucket.app_storage[0].bucket : "S3 Storage disabled (var.enable_s3_storage = false)"
}

output "sns_topic_arn" {
  description = "ARN SNS Topic untuk notifikasi laporan ekonomi (didukung penuh di AWS Academy)"
  value       = aws_sns_topic.reports.arn
}

output "deployment_instructions" {
  description = "Panduan pengujian dan verifikasi akses aplikasi"
  value       = <<EOT
================================================================================
KOPDES MERAH PUTIH - AWS NATIVE INFRASTRUCTURE DEPLOYED!
================================================================================
1. Akses Aplikasi Web:
   Buka browser dan akses URL: http://${aws_lb.alb.dns_name}

2. Akun Demo Login:
   - HEAD_GOV : head@gov.local / password123
   - MANAGER  : manager@gov.local / password123
   - CITIZEN  : citizen@gov.local / password123

3. Pengujian Report Notifikasi via Amazon SNS:
   Masuk sebagai HEAD_GOV -> Menu Laporan -> Klik tombol "Kirim via Email (SNS)".

4. Monitoring & Auto Scaling:
   - Cek Target Group Health di AWS Console (EC2 -> Target Groups -> ${aws_lb_target_group.alb_tg.name}).
================================================================================
EOT
}
