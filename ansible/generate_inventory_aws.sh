#!/bin/bash
# ==============================================================================
# Helper Script: Generate Ansible Inventory from AWS EC2 Instances
# Mengambil IP private instance EC2 yang sedang berjalan dari Auto Scaling Group
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="${PROJECT_NAME:-kopdes-merah-putih}"
OUTPUT_FILE="$(dirname "$0")/inventory.ini"

echo "[INFO] Mengambil daftar instance EC2 untuk proyek '$PROJECT_TAG' di region $REGION..."

INSTANCES=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running" \
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
ansible_user=ec2-user
ansible_ssh_private_key_file=~/.ssh/kopdes-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
ansible_become=yes
ansible_become_method=sudo
EOF

echo "[OK] File inventory berhasil di-generate di $OUTPUT_FILE"
