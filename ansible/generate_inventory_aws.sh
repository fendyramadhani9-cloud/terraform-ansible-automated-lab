#!/bin/bash
# ==============================================================================
# Helper Script: Generate Ansible Inventory from AWS EC2 Instances
# Mengambil IP private instance EC2 yang sedang berjalan dari Auto Scaling Group
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="${PROJECT_NAME:-kopdes}"
OUTPUT_FILE="$(dirname "$0")/inventory.ini"

echo "[INFO] Mengambil daftar instance EC2 untuk proyek '$PROJECT_TAG' di region $REGION..."

INSTANCES=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT_TAG,kopdes-merah-putih" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" \
    --output json)

COUNT=$(echo "$INSTANCES" | jq '.[][] | length' | wc -l)

echo "[INFO] Ditemukan $COUNT instance running."

cat <<EOF > "$OUTPUT_FILE"
# ==============================================================================
# ANSIBLE INVENTORY: GENERATED SECARA DINAMIS VIA AWS CLI
# Generated pada: $(date)
# Region: $REGION | Proyek: $PROJECT_TAG
# ==============================================================================

[webservers]
EOF

INDEX=1
echo "$INSTANCES" | jq -c '.[][]' | while read -r item; do
    IP=$(echo "$item" | jq -r '.[1]')
    NAME=$(echo "$item" | jq -r '.[2]')
    [ "$NAME" = "null" ] && NAME="kopdes-web-asg-$INDEX"
    echo "$NAME ansible_host=$IP server_node_name=WEB-0$INDEX" >> "$OUTPUT_FILE"
    INDEX=$((INDEX+1))
done

cat <<EOF >> "$OUTPUT_FILE"

[webservers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/labsuser.pem
# Catatan Jaringan: Instance berada di private subnet tanpa public IP.
# Jika menjalankan Ansible via SSH dari workstation luar VPC, gunakan AWS SSM ProxyCommand:
# ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p"'
# Atau jalankan inisialisasi praktis tanpa SSH via SSM Run Command: bash ansible/run_db_init_ssm.sh
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
ansible_become=yes
ansible_become_method=sudo
EOF

echo "[OK] File inventory berhasil di-generate di $OUTPUT_FILE"
echo "[TIP] Untuk inisialisasi database di private subnet tanpa perlu SSH, Anda dapat menjalankan:"
echo "      bash ansible/run_db_init_ssm.sh"
