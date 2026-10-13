# Panduan Lengkap Deployment AWS Native: KopDes Merah Putih

Panduan ini menyajikan tutorial langkah-demi-langkah yang terperinci untuk mendeploy platform **KopDes Merah Putih** ke infrastruktur **AWS Native** menggunakan **Terraform** dan **Ansible**.

---

## Daftar Isi

1. [Prasyarat Akun dan Peralatan](#1-prasyarat-akun-dan-peralatan)
2. [Persiapan Kredensial AWS dan Key Pair](#2-persiapan-kredensial-aws-dan-key-pair)
3. [Panduan Khusus AWS Academy Learner Lab](#3-panduan-khusus-aws-academy-learner-lab)
4. [Konfigurasi Notifikasi Laporan (Amazon SES & Amazon SNS)](#4-konfigurasi-notifikasi-laporan-amazon-ses--amazon-sns)
5. [Kustomisasi Variabel Terraform](#5-kustomisasi-variabel-terraform)
6. [Urutan Provisioning Terraform](#6-urutan-provisioning-terraform)
7. [Mekanisme Bootstrap Otomatis Instance EC2 (ASG)](#7-mekanisme-bootstrap-otomatis-instance-ec2-asg)
8. [Inisialisasi dan Validasi Database Amazon RDS](#8-inisialisasi-dan-validasi-database-amazon-rds)
9. [Pengujian Akses Aplikasi Melalui ALB](#9-pengujian-akses-aplikasi-melalui-alb)
10. [Pengujian Auto Scaling, Health Check, dan Self-Healing](#10-pengujian-auto-scaling-health-check-dan-self-healing)
11. [Pengujian Fitur Pengiriman Laporan via Amazon SES / SNS](#11-pengujian-fitur-pengiriman-laporan-via-amazon-ses--sns)
12. [Manajemen Biaya dan Prosedur Teardown (Cleanup)](#12-manajemen-biaya-dan-prosedur-teardown-cleanup)

---

## 1. Prasyarat Akun dan Peralatan

Sebelum memulai proses deployment, pastikan workstation/laptop Anda telah terpasang:
- **Akun AWS**: Akun dengan hak akses Administrator atau PowerUser untuk membuat VPC, EC2, ASG, RDS, IAM, Secrets Manager, dan SES.
- **AWS CLI v2**: Terpasang dan terkonfigurasi (`aws --version`).
- **Terraform**: HashiCorp Terraform v1.5.0 atau lebih baru (`terraform -version`).
- **Git**: Untuk clone dan manipulasi kode sumber repository.
- **OpenSSH Client**: Untuk debugging instance EC2 (jika diperlukan).

---

## 2. Persiapan Kredensial AWS dan Key Pair

### A. Autentikasi AWS CLI
Pastikan AWS CLI telah diautentikasi dengan benar. Disarankan menggunakan named profile atau environment variables (jangan menanam kredensial statis di source code):

```bash
# Opsi 1: Menggunakan AWS Configure
aws configure

# Opsi 2: Menggunakan Environment Variables
export AWS_ACCESS_KEY_ID="AKIAxxxxxxxxxxxxxxxx"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_DEFAULT_REGION="us-east-1"

# Verifikasi identitas caller
aws sts get-caller-identity
```

### B. Membuat EC2 Key Pair (Opsional untuk SSH Debugging)
Buat EC2 Key Pair di region target (`us-east-1`):

```bash
aws ec2 create-key-pair \
  --key-name kopdes-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/kopdes-key.pem

chmod 400 ~/.ssh/kopdes-key.pem
```

---

## 3. Panduan Khusus AWS Academy Learner Lab

> [!TIP]
> **Karakteristik & Batasan AWS Academy Learner Lab:**
> - **IAM Roles**: Mahasiswa **tidak diizinkan** mengeksekusi `iam:CreateRole` atau `iam:CreateInstanceProfile`. Solusi pada repo ini: telah disediakan opsi `use_aws_academy = true` di Terraform yang otomatis menggunakan role bawaan `LabRole` dan instance profile `LabInstanceProfile`.
> - **Elastic IP Quota**: AWS Academy membatasi kuota Elastic IP sebanyak **tepat 1 EIP**. Arsitektur ini menggunakan `single_nat_gateway = true` sehingga tepat menggunakan 1 EIP tanpa melebihi batas kuota.
> - **Amazon SES vs SNS**: Layanan SES seringkali dibatasi oleh SCP. Repositori ini otomatis menyediakan **Amazon SNS Topic & Email Subscription** sebagai mekanisme pengiriman notifikasi/laporan yang diizinkan 100% di lab.
> - **Session Token**: Kredensial Learner Lab memiliki `aws_session_token` yang kedaluwarsa setiap 4 jam. Jangan lupa memperbarui kredensial via AWS CLI atau environment variables saat sesi lab di-restart.

---

## 4. Konfigurasi Notifikasi Laporan (Amazon SES & Amazon SNS)

Di akun AWS standar, Amazon SES dapat digunakan setelah verifikasi identitas email. Di **AWS Academy Learner Lab**, notifikasi otomatis diarahkan melalui **Amazon SNS**:

### Alur Kerja Notifikasi:
1. Terraform membuat topik **Amazon SNS** (`kopdes-economic-reports-topic`) dan langganan email (`aws_sns_topic_subscription`) ke email `ses_recipient_email`.
2. Saat `terraform apply` selesai, AWS SNS mengirim email verifikasi bertajuk **"AWS Notification - Subscription Confirmation"** ke inbox email tujuan.
3. Buka email tersebut lalu klik tautan **Confirm subscription**.
4. Saat tombol **"Kirim via Email"** ditekan di dashboard aplikasi KopDes, sistem mempublikasikan laporan ke topik SNS, dan Amazon SNS mendistribusikan email laporan ke seluruh pelanggan terdaftar.

---

## 5. Kustomisasi Variabel Terraform

Salin template variabel lingkungan:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit file `terraform/terraform.tfvars` dan sesuaikan parameter berikut:

```hcl
aws_region   = "us-east-1"
project_name = "kopdes-merah-putih"
environment  = "lab"

# Konfigurasi Jaringan VPC
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnets  = ["10.0.10.0/24", "10.0.11.0/24"]
private_db_subnets   = ["10.0.20.0/24", "10.0.21.0/24"]

# Efisiensi Biaya Lab & Kuota AWS Academy (1 EIP):
single_nat_gateway   = true

# Mode Khusus AWS Academy Learner Lab:
use_aws_academy              = true
academy_instance_profile_name = "LabInstanceProfile"

# Kapasitas Auto Scaling Group
asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4
ec2_instance_type    = "t3.small"

# Konfigurasi Amazon RDS (Single-AZ untuk menghemat saldo lab)
rds_instance_class   = "db.t4g.micro"
rds_allocated_storage = 20
rds_db_name          = "kopdes"
rds_db_username      = "kopdes_admin"
rds_multi_az         = false

# Konfigurasi Notifikasi Laporan
ses_sender_email     = "noreply@kopdes.id"
ses_recipient_email  = "email_anda@domain.com" # Ganti dengan email Anda

# Storage Opsional
enable_s3_storage    = false
```

---

## 6. Urutan Provisioning Terraform

Jalankan perintah berikut di dalam direktori `terraform/`:

### A. Validasi Statis Kode
```bash
# Periksa formatting
terraform fmt -check

# Inisialisasi provider AWS
terraform init

# Validasi sintaks deklarasi resource
terraform validate
```

### B. Pratinjau Perubahan (Dry-Run Plan)
```bash
terraform plan -out=tfplan
```
Periksa kembali daftar resource yang akan dibuat:
- 1 VPC + 1 Internet Gateway + 1 NAT Gateway + 6 Subnet (2 Public, 2 Private App, 2 Private DB)
- 3 Security Groups (ALB, EC2, RDS)
- 1 RDS Instance MySQL + 1 DB Subnet Group + 1 AWS Secrets Manager Secret
- 1 IAM Role + Instance Profile (SES + SSM)
- 1 Application Load Balancer + 1 Target Group + 1 HTTP Listener
- 1 Launch Template + 1 Auto Scaling Group

### C. Menerapkan Infrastruktur (Apply)
> [!IMPORTANT]
> Hanya jalankan perintah ini jika Anda telah siap membuat resource cloud di akun AWS Anda.

```bash
terraform apply "tfplan"
```

Setelah selesai (~8-12 menit untuk pembuatan RDS), Terraform akan mencetak output:

```text
Apply complete! Resources: 38 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name = "kopdes-alb-123456789.us-east-1.elb.amazonaws.com"
asg_name = "kopdes-merah-putih-web-asg"
rds_endpoint = "kopdes-merah-putih-rds.c3xxxxxx.us-east-1.rds.amazonaws.com:3306"
vpc_id = "vpc-0abc123456789def0"
```

---

## 7. Mekanisme Bootstrap Otomatis Instance EC2 (ASG)

Setiap instance yang diluncurkan oleh ASG akan menjalankan `user_data.sh.tftpl`:
1. Sistem operasi Amazon Linux 2023 memperbarui paket dan menginstal `git`, `python3`, dan `ansible-core`.
2. Repositori di-clone ke `/opt/kopdes`.
3. Ansible dijalankan secara lokal:
   ```bash
   ansible-playbook -i "localhost," -c local /opt/kopdes/ansible/playbook_app.yml
   ```
4. Ansible mengonfigurasi pool `php-fpm` (Unix socket `/run/php-fpm/www.sock`), virtual host Nginx port 80, file `.env` dengan kredensial RDS dari Terraform, dan menyalakan systemd service.
5. Skrip mengeksekusi migrasi database ke Amazon RDS secara idempotent.

### Cara Memantau Log Bootstrap:
Jika Anda terhubung via AWS SSM Session Manager atau Bastion Host:
```bash
# Pantau log user-data secara real-time
tail -f /var/log/user-data.log

# Cek status service Nginx & PHP-FPM
systemctl status nginx
systemctl status php-fpm
```

---

## 8. Inisialisasi dan Validasi Database Amazon RDS

Mekanisme inisialisasi database terpusat di `database/init.php`:
1. Skrip secara otomatis dieksekusi saat bootstrap instance pertama.
2. Skrip membaca koneksi dari environment `.env` (`DB_HOST`, `DB_USER`, `DB_PASS`).
3. Mengimpor `database/schema.sql` (tabel `users`, `kopdes`, `memberships`, `products`, `transactions`, `audit_logs`).
4. Mengimpor `database/seed.sql` berisi 15 akun pengguna demo, 15 unit KopDes wilayah Banyumas, produk, dan transaksi.
5. Karena menggunakan sintaks `INSERT IGNORE`, skrip bersifat **100% idempotent** dan aman dijalankan ulang.

---

## 9. Pengujian Akses Aplikasi Melalui ALB

Buka browser dan akses alamat DNS yang tercantum di output `alb_dns_name`:

```text
http://<alb_dns_name>/
```

### Akun Uji Coba Default:
1. **Kepala Wilayah (Administrator)**:
   - Email: `head@gov.local`
   - Password: `password123`
   - Fitur: Laporan ekonomi wilayah, pemantauan status cluster AWS Native (ALB, ASG, RDS), dan pengiriman email laporan via SES/SNS.
2. **Pengelola Unit Koperasi (Manager)**:
   - Email: `manager@gov.local` s.d. `manager15@gov.local`
   - Password: `password123`
   - Fitur: Kasir POS, stok produk desa, pendaftaran warga.
3. **Warga Desa (Citizen)**:
   - Email: `citizen@gov.local` (atau register baru)
   - Password: `password123`
   - Fitur: Katalog komoditas, belanja online desa.

---

## 10. Pengujian Auto Scaling, Health Check, dan Self-Healing

### A. Pengujian Target Group Health Check
Di AWS Console (EC2 > Target Groups) atau via AWS CLI:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-east-1
```
Pastikan kedua target berada dalam kondisi **healthy** (HTTP 200 pada `/index.php?page=login`).

### B. Simulasi Kegagalan Instance (Self-Healing Test)
1. Matikan (terminate) salah satu instance EC2 yang sedang berjalan di ASG:
   ```bash
   aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region us-east-1
   ```
2. Amati Application Load Balancer:
   - ALB mendeteksi instance yang mati dan menghentikan rute trafik ke instance tersebut tanpa *downtime* bagi pengguna.
3. Amati Auto Scaling Group:
   - ASG mendeteksi bahwa jumlah instance aktif berkurang di bawah *desired capacity* (2).
   - ASG secara otomatis meluncurkan instance EC2 baru.
   - Instance baru mengeksekusi bootstrap cloud-init dan Ansible secara lokal.
   - Dalam ~2-3 menit, instance baru otomatis bergabung ke Target Group dan berstatus *healthy*.

---

## 11. Pengujian Fitur Pengiriman Laporan via Amazon SES / SNS

1. Login sebagai Kepala Wilayah: `head@gov.local` / `password123`.
2. Buka menu **Laporan Ekonomi** (`pages/headgov/reports.php`).
3. Pada kartu laporan atau tombol tindakan, klik **"Kirim via Email (SNS)"**.
4. Sistem akan:
   - Memanggil `includes/ses_mailer.php` (didukung alias `SnsMailer` / `NotificationService`).
   - Mengambil kredensial dinamis dari IAM Instance Profile via IMDSv2.
   - Mempublikasikan email ringkasan omzet, surplus usaha, dan transaksi aktif ke topik Amazon SNS (`kopdes-economic-reports-topic`).
   - Amazon SNS langsung mendistribusikan email laporan ke `sns_recipient_email`.
   - Menampilkan notifikasi sukses di antarmuka web.
5. Buka kotak masuk email tujuan untuk melihat format laporan yang diterima.

---

## 12. Manajemen Biaya dan Prosedur Teardown (Cleanup)

### Tips Menghemat Biaya Selama Pengujian:
- Gunakan Single-AZ RDS (`rds_multi_az = false`).
- Gunakan Single NAT Gateway (`single_nat_gateway = true`).
- Hancurkan infrastruktur jika sesi belajar/pengujian telah selesai.

### Prosedur Penghancuran (Teardown):

```bash
cd terraform
terraform destroy
```

Ketik `yes` saat konfirmasi diminta. Seluruh resource (VPC, NAT Gateway, ALB, ASG, EC2, RDS, SNS Topic, dan Secrets Manager) akan dihapus secara bersih sehingga tagihan AWS berhenti berjalan.
