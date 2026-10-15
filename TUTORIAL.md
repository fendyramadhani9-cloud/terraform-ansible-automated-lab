# Panduan Lengkap Deployment AWS Native: KopDes Merah Putih
## Menggunakan Terraform & Ansible di AWS Academy Learner Lab

Panduan ini menyajikan instruksi komprehensif langkah-demi-langkah mulai dari instalasi peralatan dasar (*prerequisites*), konfigurasi kredensial AWS Academy, penyediaan infrastruktur *AWS Native* dengan **Terraform**, otomasi konfigurasi server dengan **Ansible**, integrasi notifikasi **Amazon SNS**, hingga pengujian aplikasi dan prosedur *teardown* (pembersihan resource).

---

## Daftar Isi

1. [Prasyarat & Panduan Instalasi Peralatan Lengkap](#1-prasyarat--panduan-instalasi-peralatan-lengkap)
   - [A. Instalasi AWS CLI v2](#a-instalasi-aws-cli-v2)
   - [B. Instalasi HashiCorp Terraform](#b-instalasi-hashicorp-terraform)
   - [C. Instalasi Git & SSH Client](#c-instalasi-git--ssh-client)
   - [D. Verifikasi Instalasi Seluruh Peralatan](#d-verifikasi-instalasi-seluruh-peralatan)
2. [Persiapan Kredensial AWS Academy & Key Pair 'vockey'](#2-persiapan-kredensial-aws-academy--key-pair-vockey)
   - [A. Memulai Lab & Menyalin Kredensial AWS CLI](#a-memulai-lab--menyalin-kredensial-aws-cli)
   - [B. Mengatur Environment Variables Kredensial](#b-mengatur-environment-variables-kredensial)
   - [C. Verifikasi Akses AWS CLI](#c-verifikasi-akses-aws-cli)
   - [D. Mengunduh EC2 Key Pair Bawaan ('vockey')](#d-mengunduh-ec2-key-pair-bawaan-vockey)
3. [Karakteristik & Kebijakan Khusus AWS Academy Learner Lab](#3-karakteristik--kebijakan-khusus-aws-academy-learner-lab)
4. [Mekanisme Notifikasi Laporan via Amazon SNS (Bebas dari SES)](#4-mekanisme-notifikasi-laporan-via-amazon-sns-bebas-dari-ses)
5. [Kloning Repositori & Kustomisasi Variabel Terraform](#5-kloning-repositori--kustomisasi-variabel-terraform)
6. [Urutan Provisioning Infrastruktur (Terraform)](#6-urutan-provisioning-infrastruktur-terraform)
7. [Mekanisme Bootstrap Otomatis EC2 (Cloud-Init & Ansible)](#7-mekanisme-bootstrap-otomatis-ec2-cloud-init--ansible)
8. [Inisialisasi dan Validasi Database Amazon RDS](#8-inisialisasi-dan-validasi-database-amazon-rds)
9. [Pengujian Akses Aplikasi Melalui Application Load Balancer](#9-pengujian-akses-aplikasi-melalui-application-load-balancer)
10. [Pengujian Auto Scaling, Target Group Health Check, & Self-Healing](#10-pengujian-auto-scaling-target-group-health-check--self-healing)
11. [Pengujian Pengiriman Laporan Ekonomi via Amazon SNS](#11-pengujian-pengiriman-laporan-ekonomi-via-amazon-sns)
12. [Manajemen Saldo Lab & Prosedur Teardown (Cleanup)](#12-manajemen-saldo-lab--prosedur-teardown-cleanup)

---

## 1. Prasyarat & Panduan Instalasi Peralatan Lengkap

Sebelum memulai deployment, pastikan komputer/laptop lokal Anda telah terpasang peralatan CLI berikut:

### A. Instalasi AWS CLI v2

#### 1. Windows:
* **Via Windows Package Manager (winget)**:
  ```powershell
  winget install Amazon.AWSCLI
  ```
* **Atau Unduh Installer Resmi (MSI)**:
  Unduh dan jalankan file installer dari [AWS CLI MSI Installer](https://awscli.amazonaws.com/AWSCLIV2.msi).

#### 2. Linux (Ubuntu / Debian / RHEL / CentOS):
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

#### 3. macOS:
* **Via Homebrew**:
  ```bash
  brew install awscli
  ```
* **Atau Unduh Package Resmi**:
  Unduh installer dari [AWS CLI macOS PKG](https://awscli.amazonaws.com/AWSCLIV2.pkg).

---

### B. Instalasi HashiCorp Terraform

Diperlukan Terraform versi **v1.5.0** atau lebih baru.

#### 1. Windows:
* **Via Winget**:
  ```powershell
  winget install HashiCorp.Terraform
  ```
* **Via Chocolatey**:
  ```powershell
  choco install terraform
  ```

#### 2. Linux (Ubuntu / Debian):
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```

#### 3. macOS:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

---

### C. Instalasi Git & SSH Client

* **Windows**: Unduh [Git for Windows](https://git-scm.com/download/win) (sudah termasuk Git Bash & OpenSSH Client) atau jalankan `winget install Git.Git`.
* **Linux**: Jalankan `sudo apt install -y git openssh-client` atau `sudo dnf install -y git openssh-clients`.
* **macOS**: Jalankan `brew install git`.

---

### D. Verifikasi Instalasi Seluruh Peralatan

Buka terminal baru dan jalankan perintah verifikasi berikut:

```bash
aws --version
terraform -version
git --version
```
Pastikan seluruh perintah menghasilkan output versi tanpa pesan error.

---

## 2. Persiapan Kredensial AWS Academy & Key Pair 'vockey'

AWS Academy Learner Lab menggunakan kredensial sementara (*temporary session credentials*) yang mencakup **AWS Session Token**. Token ini berlaku hingga maksimal **4 jam**.

### A. Memulai Lab & Menyalin Kredensial AWS CLI

1. Masuk ke portal **AWS Academy** dan buka kursus Anda $\rightarrow$ Pilih **Learner Lab**.
2. Klik tombol **Start Lab** di kanan atas.
3. Tunggu hingga lingkaran indikator di samping tulisan **AWS** berubah menjadi warna hijau stabil.
4. Klik tombol **AWS Details** (di sebelah kanan tulisan *Start Lab*).
5. Pada panel yang muncul, cari baris **AWS CLI**, lalu klik tautan **Show**.
6. Anda akan melihat blok teks kredensial seperti berikut:
   ```text
   [default]
   aws_access_key_id=ASIAXXXXXXXXXXXXXXXX
   aws_secret_access_key=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   aws_session_token=IQoJb3JpZ2luX2VjEPH//////////...
   ```

---

### B. Mengatur Environment Variables Kredensial

Salin nilai kredensial di atas ke terminal aktif tempat Anda akan mengeksekusi Terraform:

#### 1. Jika Menggunakan Windows PowerShell:
```powershell
$env:AWS_ACCESS_KEY_ID="ASIAXXXXXXXXXXXXXXXX"
$env:AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$env:AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEPH//////////..."
$env:AWS_DEFAULT_REGION="us-east-1"
```

#### 2. Jika Menggunakan Linux / macOS / Git Bash:
```bash
export AWS_ACCESS_KEY_ID="ASIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEPH//////////..."
export AWS_DEFAULT_REGION="us-east-1"
```

#### 3. Atau Simpan ke File Kredensial Lokal:
Buat atau perbarui file `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = ASIAXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
aws_session_token = IQoJb3JpZ2luX2VjEPH//////////...
region = us-east-1
```

> [!WARNING]
> Kredensial sesi lab akan kedaluwarsa setelah sesi lab di-restart atau setelah 4 jam. Jika di tengah pekerjaan Terraform Anda menemui error `ExpiredToken`, ulangi langkah di atas dengan menyalin kredensial terbaru dari panel **AWS Details**.

---

### C. Verifikasi Akses AWS CLI

Jalankan perintah ini untuk memastikan kredensial telah aktif dan terbaca:

```bash
aws sts get-caller-identity
```

Output yang benar akan menampilkan identitas akun lab:
```json
{
    "UserId": "AROA...:voclabs",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/LabRole/voclabs"
}
```

---

### D. Mengunduh EC2 Key Pair Bawaan ('vockey')

Di AWS Academy Learner Lab, Anda **tidak perlu** membuat key pair baru. AWS Academy secara default telah menyediakan key pair bernama **`vockey`** di region `us-east-1`.

1. Pada panel **AWS Details** yang sama di konsol lab, cari bagian **SSH Key**.
2. Klik tautan unduh **Download PEM** (file akan bernama `labsuser.pem`).
3. Pindahkan file tersebut ke folder SSH workstation Anda dan amankan permission-nya:
   ```bash
   # Di Linux / macOS / WSL / Git Bash:
   mkdir -p ~/.ssh
   mv ~/Downloads/labsuser.pem ~/.ssh/labsuser.pem
   chmod 400 ~/.ssh/labsuser.pem
   ```
4. Key pair ini nantinya otomatis dihubungkan ke seluruh instance EC2 yang dibuat oleh Auto Scaling Group melalui parameter `key_name = "vockey"`.

---

## 3. Karakteristik & Kebijakan Khusus AWS Academy Learner Lab

Infrastruktur ini telah didesain khusus agar **100% kompatibel** dengan aturan dan limitasi AWS Academy Learner Lab:

1. **Kebijakan IAM (No Create Role)**:
   - Akun mahasiswa dilarang mengeksekusi `iam:CreateRole` atau `iam:CreateInstanceProfile` oleh SCP (*Service Control Policy*).
   - **Solusi**: Konfigurasi Terraform menyertakan opsi `use_aws_academy = true`. Terraform tidak akan mencoba membuat role baru, melainkan langsung menggunakan IAM Role bawaan lab: **`LabRole`** dan Instance Profile **`LabInstanceProfile`**.
2. **Kuota Elastic IP (Maksimum 1 EIP)**:
   - AWS Academy hanya memberikan kuota **tepat 1 Elastic IP per akun**.
   - **Solusi**: Konfigurasi jaringan disetel ke `single_nat_gateway = true`. Seluruh private subnet merutekan trafik keluar melalui 1 NAT Gateway di Public Subnet AZ-a, sehingga pemakaian Elastic IP tepat 1 unit dan tidak melebihi kuota.
3. **Pemberhentian Layanan CloudWatch**:
   - Untuk menghemat alokasi biaya lab dan mencegah error izin policy, resource CloudWatch Log Group telah dihapus total. Pemantauan log dilakukan secara aman pada level instance melalui file `/var/log/user-data.log` dan systemd journal.
4. **Amazon SES Dihapus $\rightarrow$ Digantikan Amazon SNS**:
   - Amazon Simple Email Service (SES) diblokir oleh SCP di AWS Academy dan membutuhkan proses *sandbox unban* yang tidak diizinkan untuk akun mahasiswa.
   - **Solusi**: Laporan ekonomi wilayah menggunakan **Amazon SNS (Simple Notification Service)** yang didukung penuh oleh `LabRole` dan otomatis mengirimkan email ke inbox subscriber.
5. **Kunci Region Target**:
   - Seluruh konfigurasi resource dan AMI dikunci secara presisi pada region **`us-east-1`** (N. Virginia), sesuai dengan region resmi AWS Academy Learner Lab.
6. **Optimasi Anggaran Lab ($100 Credit Limit)**:
   - Menggunakan Single-AZ RDS MySQL (`db.t4g.micro`), EC2 `t3.micro`, dan auto termination saat sesi lab selesai agar kredit lab Anda tetap hemat dan aman.

---

## 4. Mekanisme Notifikasi Laporan via Amazon SNS (Bebas dari SES)

Sistem notifikasi laporan ekonomi desa menggunakan **Amazon Simple Notification Service (SNS)**:

```
[Web App KopDes (EC2 / ASG)]
           │
           │ (REST API SigV4 via IMDSv2 Role: LabRole)
           ▼
[Amazon SNS Topic: kopdes-economic-reports-topic]
           │
           │ (Email Dispatch Protocol)
           ▼
[Email Administrator: sns_recipient_email]
```

### Keunggulan Alur Amazon SNS:
1. **Didukung 100% di AWS Academy**: IAM Role bawaan `LabRole` memiliki izin penuh untuk mempublikasikan pesan ke Amazon SNS (`sns:Publish`).
2. **Tanpa Perlu Domain Sendiri**: Tidak memerlukan DNS verification, MX record, atau DKIM.
3. **Konfirmasi Langganan Otomatis**:
   - Saat `terraform apply` dijalankan, Terraform mendaftarkan email Anda (`sns_recipient_email`) ke topik SNS.
   - AWS SNS mengirim email verifikasi bertajuk **"AWS Notification - Subscription Confirmation"**.
   - Anda cukup membuka email tersebut dan mengklik tautan **Confirm subscription**.
   - Setelah statusnya terkonfirmasi, setiap kali pengurus desa mengklik tombol **"Kirim via Email (SNS)"** di dashboard, laporan rekapitulasi ekonomi langsung terdistribusi ke email Anda.

---

## 5. Kloning Repositori & Kustomisasi Variabel Terraform

### A. Clone Repositori IaC
Buka terminal Anda dan clone repositori otomasi infrastruktur:

```bash
git clone https://github.com/fendyramadhani9-cloud/terraform-ansible-automated-lab.git
cd terraform-ansible-automated-lab/terraform
```

---

### B. Menyiapkan File Variabel (`terraform.tfvars`)
Salin file template `terraform.tfvars.example` menjadi `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Buka file `terraform.tfvars` dengan text editor (misal VS Code, Notepad, atau Nano), lalu periksa parameternya:

```hcl
# ==============================================================================
# KopDes Merah Putih - AWS Academy Learner Lab Configuration
# ==============================================================================

aws_region   = "us-east-1"
project_name = "kopdes"
environment  = "production"

# AWS Academy Compatibility Mode (Wajib true untuk Learner Lab)
use_aws_academy               = true
academy_instance_profile_name = "LabInstanceProfile"

# Jaringan VPC (Multi-AZ di us-east-1a dan us-east-1b)
vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]

# Efisiensi Kuota AWS Academy: Tepat 1 Elastic IP untuk 1 NAT Gateway
single_nat_gateway       = true

# Compute Tier (EC2 Auto Scaling Group)
instance_type        = "t3.micro"
key_name             = "vockey" # EC2 Key Pair bawaan AWS Academy
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

# Database Tier (Amazon RDS MySQL 8.4 LTS)
db_engine_version    = "8.4"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_multi_az          = false # Wajib false untuk efisiensi lab
db_name              = "kopdes"
db_username          = "kopdes_admin"

# Notifikasi Laporan via Amazon SNS (Ganti dengan email aktif Anda)
sns_recipient_email  = "email_anda@gmail.com"

# Storage Eksternal
enable_s3_storage    = false

# Alamat Repositori GitHub
git_repo_url = "https://github.com/fendyramadhani9-cloud/kopdes-landingPAGE.git"
iac_repo_url = "https://github.com/fendyramadhani9-cloud/terraform-ansible-automated-lab.git"
```

> [!IMPORTANT]
> Pastikan Anda mengganti nilai `sns_recipient_email` dengan alamat email Anda yang valid agar Anda dapat menerima email konfirmasi langganan dan email laporan.

---

## 6. Urutan Provisioning Infrastruktur (Terraform)

Jalankan perintah berikut secara berurutan di dalam direktori `terraform/`:

### A. Inisialisasi Provider AWS
Mengunduh provider AWS dan HashiCorp Random:
```bash
terraform init
```

### B. Validasi Kode Terraform
Memastikan seluruh sintaks, struktur blok, dan referensi resource valid:
```bash
terraform validate
```
*Output yang diharapkan:* `Success! The configuration is valid.`

### C. Pratinjau Perubahan (Dry-Run Plan)
Melihat daftar 32+ resource cloud yang akan dibuat:
```bash
terraform plan -out=tfplan
```

### D. Terapkan Infrastruktur (Apply)
Eksekusi pembuatan infrastruktur cloud secara otomatis:
```bash
terraform apply "tfplan"
```

> [!NOTE]
> Proses provisioning membutuhkan waktu sekitar **8 hingga 12 menit**, terutama saat pembuatan Amazon RDS MySQL Instance. Biarkan proses berjalan hingga selesai.

### E. Output Informasi Infrastruktur
Setelah selesai, Terraform akan menampilkan output seperti berikut:

```text
Apply complete! Resources: 34 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name = "http://kopdes-alb-123456789.us-east-1.elb.amazonaws.com"
asg_name = "kopdes-asg-xxxxxxxx"
rds_endpoint = "kopdes-rds-mysql.cxxxxxx.us-east-1.rds.amazonaws.com:3306"
sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:kopdes-economic-reports-topic"
vpc_id = "vpc-0123456789abcdef0"
```

---

## 7. Mekanisme Bootstrap Otomatis EC2 (Cloud-Init & Ansible)

Setiap kali instance EC2 baru diluncurkan oleh Auto Scaling Group, skrip template `user_data.sh.tftpl` akan dieksekusi secara otomatis:

1. **Pembaruan OS**: Memperbarui paket sistem operasi **Ubuntu 24.04 LTS (Noble Numbat)** via `apt-get` dan menginstal `git`, `python3`, `jq`, `awscli`, dan `ansible-core`.
2. **Kloning Repositori**:
   - Meng-clone repositori IaC (`terraform-ansible-automated-lab`) ke folder `/opt/kopdes-iac`.
   - Meng-clone repositori Web Application (`kopdes-landingPAGE`) ke folder `/var/www/kopdes`.
3. **Eksekusi Ansible Lokal**:
   Ansible dijalankan secara lokal pada node untuk mengonfigurasi webserver:
   ```bash
   ansible-playbook -i "localhost," -c local /opt/kopdes-iac/ansible/playbook_app.yml ...
   ```
   - Menginstal Nginx dan PHP 8.3 (dengan ekstensi `php-mysql`, `curl`, `mbstring`, `zip`, `xml`, `bcmath`).
   - Mengonfigurasi Unix domain socket PHP-FPM (`/run/php/php-fpm.sock`).
   - Menghasilkan file konfigurasi `.env` berisi endpoint RDS, ALB DNS, dan ARN SNS Topic (password diambil aman dari AWS Secrets Manager).
   - Mengonfigurasi virtual host Nginx port 80 dan mengaktifkan systemd service (`php8.3-fpm` dan `nginx`).
4. **Kesiapan Node**: Node langsung siap menerima request HTTP dari ALB secara stateless tanpa menyentuh atau mereset data database. Inisialisasi skema DB dilakukan terpisah secara one-time via `playbook_db_init.yml`.

### Cara Memantau Log Bootstrap (Opsional):
Jika Anda terhubung ke instance via SSH (menggunakan `labsuser.pem`) atau AWS Systems Manager:
```bash
tail -f /var/log/user-data.log
```

---

## 8. Inisialisasi dan Validasi Database Amazon RDS

Inisialisasi database Amazon RDS dirancang **100% idempotent** dan **concurrency-safe** menggunakan *MySQL Advisory Lock* (`GET_LOCK`), skema `CREATE TABLE IF NOT EXISTS`, dan sinkronisasi seed non-destruktif.

### Opsi A: Otomatis saat Bootstrap EC2 (Fail-Fast & Zero-Touch)
Setiap instance EC2 yang diluncurkan oleh Auto Scaling Group menjalankan inisialisasi skema & seed secara otomatis dengan prinsip **fail-fast**: jika koneksi database atau lock gagal, proses bootstrap langsung berhenti (`exit 1`) sehingga instance tidak akan dilaporkan sebagai sehat (*Healthy*) oleh ALB sebelum database benar-benar siap. Berkat *MySQL Advisory Lock* (`GET_LOCK`), instance-instance ASG tidak akan mengalami *race condition* dan tidak akan menimpa data transaksi pengguna.

### Opsi B: Eksekusi Manual via AWS Systems Manager (Rekomendasi di AWS Academy)
Karena instance EC2 berada di *private subnet* tanpa public IP, cara paling andal menjalankan inisialisasi dari komputer lokal Anda (tanpa perlu SSH, VPN, atau Bastion) adalah menggunakan helper AWS SSM:

```bash
bash ansible/run_db_init_ssm.sh
```

Skrip ini akan:
1. Menemukan instance EC2 webserver yang sedang running secara otomatis via AWS CLI.
2. Mengirim perintah eksekusi `php /var/www/kopdes/database/init.php` melalui **AWS Systems Manager (SSM)**.
3. Menampilkan status dan log inisialisasi tabel (`users`, `kopdes`, `memberships`, `products`, `transactions`) serta 15 unit KopDes wilayah Banyumas secara transparan.

### Opsi C: Eksekusi via Ansible Playbook (Jika Menggunakan Bastion / SSH SSM Plugin)
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook_db_init.yml
```

---

## 9. Pengujian Akses Aplikasi Melalui Application Load Balancer

1. Buka browser web favorit Anda (Chrome, Firefox, Edge, Safari).
2. Salin nilai output `alb_dns_name` yang dihasilkan oleh Terraform, contoh:
   ```text
   http://kopdes-alb-123456789.us-east-1.elb.amazonaws.com
   ```
3. Anda akan disambut oleh halaman login KopDes Merah Putih dengan animasi transisi yang mulus.

### Kredensial Akun Pengujian:

| Role Pengguna | Alamat Email | Password | Hak Akses Utama |
| :--- | :--- | :--- | :--- |
| **Kepala Wilayah (HEAD_GOV)** | `head@gov.local` | `password123` | Dashboard agregat wilayah, peta sebaran 15 KopDes, pemantauan cluster ALB/ASG/RDS, pengiriman laporan SNS. |
| **Pengelola Koperasi (MANAGER)** | `manager@gov.local` s.d. `manager15@gov.local` | `password123` | Manajemen kasir (POS), stok komoditas desa, transaksi anggota. |
| **Warga Desa (CITIZEN)** | `citizen@gov.local` | `password123` | Katalog produk desa, keranjang belanja, checkout transaksi. |

---

## 10. Pengujian Auto Scaling, Target Group Health Check, & Self-Healing

### A. Memeriksa Status Kesehatan Target Group
Di AWS Console $\rightarrow$ Buka layanan **EC2** $\rightarrow$ **Target Groups** $\rightarrow$ Pilih `kopdes-tg`:
* Periksa tab **Targets**.
* Pastikan seluruh instance EC2 (2 unit) berstatus **Healthy** pada port 80 dengan path `/index.php?page=login`.

Atau via AWS CLI:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names kopdes-tg --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --region us-east-1
```

---

### B. Simulasi Kegagalan Instance (Uji Self-Healing)

1. Ambil salah satu Instance ID dari instance yang sedang berjalan:
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=kopdes-webserver" "Name=instance-state-name,Values=running" \
     --query 'Reservations[*].Instances[*].InstanceId' \
     --output text
   ```
2. Hentikan/matikan instance tersebut untuk mensimulasikan kegagalan server:
   ```bash
   aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region us-east-1
   ```
3. Amati perilaku sistem:
   - **Application Load Balancer**: Mendeteksi instance gagal dalam 30 detik (*unhealthy threshold*) dan otomatis mengalihkan 100% trafik ke instance sehat lainnya tanpa gangguan bagi pengguna.
   - **Auto Scaling Group**: Mendeteksi kapasitas aktif berkurang di bawah *desired capacity* (2 unit) $\rightarrow$ ASG secara otomatis meluncurkan instance EC2 baru $\rightarrow$ Cloud-init dan Ansible otomatis men-setup instance baru tersebut $\rightarrow$ Dalam 2–3 menit, instance baru bergabung ke Target Group dan berstatus *healthy*.

---

## 11. Pengujian Pengiriman Laporan Ekonomi via Amazon SNS

### Langkah 1: Konfirmasi Berlangganan Email (Subscription Confirmation)
1. Buka kotak masuk (*inbox*) email yang Anda daftarkan pada `sns_recipient_email`.
2. Cari email dari **AWS Notifications** dengan subjek **"AWS Notification - Subscription Confirmation"**.
3. Buka email tersebut dan klik tautan **Confirm subscription**.
4. Browser Anda akan menampilkan konfirmasi: *"Subscription confirmed!"*.

---

### Langkah 2: Kirim Laporan dari Dashboard Web
1. Buka URL aplikasi KopDes di browser Anda.
2. Login menggunakan akun Kepala Wilayah:
   - Email: `head@gov.local`
   - Password: `password123`
3. Masuk ke menu **Laporan Ekonomi** (`index.php?page=reports`).
4. Di bagian pojok kanan atas tabel laporan, klik tombol **"Kirim via Email (SNS)"**.
5. Antarmuka web akan menampilkan pesan notifikasi hijau:
   > *"Rekapitulasi laporan ekonomi berhasil dikirim ke email_anda@gmail.com via Amazon SNS."*
6. Buka kembali inbox email Anda. Anda akan menerima email berformat rapi berisi rekapitulasi total omzet, total transaksi selesai, jumlah anggota aktif, dan rincian unit koperasi desa.

---

## 12. Manajemen Saldo Lab & Prosedur Teardown (Cleanup)

Untuk menjaga agar kredit $100 pada AWS Academy Learner Lab tidak habis saat Anda tidak sedang menggunakan aplikasi, lakukan pembersihan resource secara berkala.

### Prosedur Penghancuran Infrastruktur:

Jalankan perintah ini di dalam direktori `terraform/`:

```bash
cd terraform-ansible-automated-lab/terraform
terraform destroy
```

1. Terraform akan menampilkan daftar seluruh resource yang akan dihapus.
2. Saat muncul konfirmasi:
   ```text
   Do you really want to destroy all resources?
     Terraform will destroy all your managed infrastructure, as shown above.
     There is no undo. Only 'yes' will be accepted to confirm.

     Enter a value:
   ```
3. Ketik **`yes`** lalu tekan Enter.
4. Terraform akan menghapus seluruh resource (ALB, Target Group, Auto Scaling Group, EC2 instances, RDS MySQL, Secrets Manager secret, SNS Topic & Subscription, NAT Gateway, Elastic IP, dan VPC) dalam waktu sekitar 3–5 menit.
5. Setelah selesai, muncul pesan:
   ```text
   Destroy complete! Resources: 34 destroyed.
   ```
6. Buka panel AWS Academy Learner Lab dan klik tombol **End Lab** untuk menghentikan penghitungan waktu sesi lab.
