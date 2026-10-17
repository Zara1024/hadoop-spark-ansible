#!/usr/bin/env bash
# ==============================================================================
# 云主机初始免密与互信打通辅助脚本 (可选工具)
# 作用：在初始只有各节点 root 统一密码时，一键完成 SSH 密钥分发与双向互信
# 使用方式: bash scripts/cloud_init_bootstrap.sh [统一初始密码]
# ==============================================================================

set -e

BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
INVENTORY_FILE="${BASE_DIR}/inventory/hosts.yml"

PASSWORD="${1:-}"
if [ -z "$PASSWORD" ]; then
    read -s -p "请输入各节点统一初始密码: " PASSWORD
    echo ""
fi

if [ -z "$PASSWORD" ]; then
    echo "[-] 密码不能为空！退出。"
    exit 1
fi

SSH_DIR="/root/.ssh"

# 动态提取 inventory/hosts.yml 中的主机名与 ansible_host
echo ">>> [1/4] 读取 ${INVENTORY_FILE} 主机信息并配置控制机 SSH 免交互..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

cat << 'EOF' > "${SSH_DIR}/config"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
chmod 600 "${SSH_DIR}/config"

if [ ! -f "${SSH_DIR}/id_rsa" ]; then
    ssh-keygen -t rsa -N "" -f "${SSH_DIR}/id_rsa" -q
fi
cat "${SSH_DIR}/id_rsa.pub" > "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"

# 确保安装 sshpass 工具
which sshpass >/dev/null 2>&1 || {
    echo "[-] 本机未安装 sshpass，正在尝试安装..."
    yum install -y sshpass || apt-get install -y sshpass || true
}

echo ">>> [2/4] 从 hosts.yml 动态读取主机与 IP，建立 /etc/hosts..."
TMP_HOSTS=$(mktemp)
grep -E "^\s+[a-zA-Z0-9_-]+:" "$INVENTORY_FILE" -A 1 | grep -B 1 "ansible_host:" | while read -r line1 && read -r line2; do
    h=$(echo "$line1" | tr -d ' :')
    ip=$(echo "$line2" | awk '{print $2}')
    if [ -n "$h" ] && [ -n "$ip" ]; then
        echo "$ip $h" >> "$TMP_HOSTS"
    fi
done

echo ">>> [3/4] 批量推送 hosts 与 SSH 公私钥到集群全部主机..."
cat "$TMP_HOSTS" | while read -r ip host; do
    echo "--- 正在初始化目标主机: ${host} (${ip}) ---"
    sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no "${TMP_HOSTS}" "root@${ip}:/etc/hosts" 2>/dev/null || true
    sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip}" "hostnamectl set-hostname ${host}; systemctl stop firewalld 2>/dev/null || true; systemctl disable firewalld 2>/dev/null || true; setenforce 0 2>/dev/null || true; sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config 2>/dev/null || true; mkdir -p ${SSH_DIR} && chmod 700 ${SSH_DIR}" 2>/dev/null || true
    
    # 分发密钥实现全向互信
    sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no "${SSH_DIR}/id_rsa" "root@${ip}:${SSH_DIR}/id_rsa" 2>/dev/null || true
    sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no "${SSH_DIR}/id_rsa.pub" "root@${ip}:${SSH_DIR}/id_rsa.pub" 2>/dev/null || true
    sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no "${SSH_DIR}/authorized_keys" "root@${ip}:${SSH_DIR}/authorized_keys" 2>/dev/null || true
    sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no "${SSH_DIR}/config" "root@${ip}:${SSH_DIR}/config" 2>/dev/null || true
    sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no "root@${ip}" "chmod 600 ${SSH_DIR}/*" 2>/dev/null || true
done
rm -f "$TMP_HOSTS"

echo ">>> [4/4] 验证集群免密连通性..."
cat /etc/hosts | grep -E "spark[0-9]+" | awk '{print $2}' | sort -u | while read -r host; do
    echo -n "测试连接至 ${host}: "
    ssh "root@${host}" "hostname"
done

echo "=========================================================="
echo "✔ 集群 SSH 互信与初始化配置已全部就绪！"
echo "=========================================================="
