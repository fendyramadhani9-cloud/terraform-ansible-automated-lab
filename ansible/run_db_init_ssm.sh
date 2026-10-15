#!/bin/bash
# ==============================================================================
# Helper Script: Run Database Initialization via AWS Systems Manager (SSM)
# ==============================================================================
# Menjalankan database/init.php pada salah satu EC2 web server di private subnet
# menggunakan AWS SSM Run Command langsung dari workstation / CloudShell / WSL.
# Tanpa membutuhkan SSH key, bastion host, ataupun public IP.
#
# Prasyarat:
# 1. AWS CLI v2 terkonfigurasi dengan kredensial AWS Academy Learner Lab.
# 2. Instance EC2 berstatus Running dan telah menyelesaikan bootstrap cloud-init.
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="${PROJECT_NAME:-kopdes}"

echo "[INFO] $(date) - Mencari instance EC2 aktif dengan Role=webserver di region $REGION..."

INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Role,Values=webserver" "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  echo "[ERROR] Tidak ditemukan EC2 webserver yang sedang running untuk proyek '$PROJECT_TAG'!" >&2
  echo "[TIP] Pastikan 'terraform apply' sudah selesai dan instance EC2 di ASG sudah berstatus running." >&2
  exit 1
fi

echo "[INFO] Menemukan target instance: $INSTANCE_ID"
echo "[INFO] Mengirim perintah inisialisasi database via AWS Systems Manager (SSM)..."

COMMAND_ID=$(aws ssm send-command \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["php /var/www/kopdes/database/init.php"]' \
  --comment "KopDes One-Time DB Initialization via SSM" \
  --query "Command.CommandId" \
  --output text)

echo "[INFO] Perintah SSM berhasil dikirim (Command ID: $COMMAND_ID). Menunggu status eksekusi..."

# Polling status eksekusi command
MAX_ATTEMPTS=30
ATTEMPT=1
STATUS="Pending"

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  sleep 4
  STATUS=$(aws ssm get-command-invocation \
    --region "$REGION" \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text 2>/dev/null || echo "Pending")

  echo "[INFO] Percobaan $ATTEMPT/$MAX_ATTEMPTS - Status SSM: $STATUS"

  if [ "$STATUS" = "Success" ] || [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ] || [ "$STATUS" = "TimedOut" ]; then
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
done

OUTPUT=$(aws ssm get-command-invocation \
  --region "$REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "[Status, ResponseCode, StandardOutputContent, StandardErrorContent]" \
  --output json 2>/dev/null || echo '["Failed", 1, "", "Gagal mengambil output eksekusi SSM invocation"]')

STATUS=$(echo "$OUTPUT" | jq -r '.[0] // empty')
RESPONSE_CODE=$(echo "$OUTPUT" | jq -r '.[1] // 1')
STDOUT=$(echo "$OUTPUT" | jq -r '.[2] // empty')
STDERR=$(echo "$OUTPUT" | jq -r '.[3] // empty')

echo "=================================================================="
echo "HASIL EKSEKUSI INISIALISASI DATABASE (AWS SSM):"
echo "Status: $STATUS | Exit Code: $RESPONSE_CODE"
echo "=================================================================="
if [ -n "$STDOUT" ]; then
  echo "$STDOUT"
fi

if [ -n "$STDERR" ]; then
  echo "[STDERR]:"
  echo "$STDERR"
fi

if [ "$STATUS" = "Success" ] && [ "$RESPONSE_CODE" = "0" ]; then
  echo "[OK] $(date) - Inisialisasi skema dan seed data Amazon RDS berhasil!"
  exit 0
else
  echo "[ERROR] Inisialisasi database via SSM gagal! (Status: $STATUS, ResponseCode: $RESPONSE_CODE)" >&2
  exit 1
fi
