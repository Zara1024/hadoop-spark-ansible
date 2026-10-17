#!/bin/bash
# ==============================================================================
# 集群 6 节点全双向免密登录自动配置脚本 (StrictHostKeyChecking=no)
# 对应 PDF 第二节 "环境准备" 第 3 项: 6 台主机任意互信 (36 次免密打通)
# ==============================================================================

set -e

HOSTS=("spark01" "spark02" "spark03" "spark04" "spark05" "spark06")
USER_NAME="root"
SSH_DIR="/root/.ssh"

echo ">>> [1/4] 配置本机 SSH 客户端默认免交互确认 (StrictHostKeyChecking=no)..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

cat << 'EOF' > "${SSH_DIR}/config"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
chmod 600 "${SSH_DIR}/config"

echo ">>> [2/4] 如果不存在本地密钥对，则自动生成..."
if [ ! -f "${SSH_DIR}/id_rsa" ]; then
    ssh-keygen -t rsa -N "" -f "${SSH_DIR}/id_rsa" -q
fi

echo ">>> [3/4] 收集并合并集群中所有主机的公钥到全局 authorized_keys..."
# 提示: 如果尚未分发公钥，需输入一次密码；或在控制机统一生成分发
cat "${SSH_DIR}/id_rsa.pub" >> "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"

# 将合并后的 authorized_keys 与私钥分发给全部 6 台主机，达成 6x6 矩阵互信
for host in "${HOSTS[@]}"; do
    echo "--- 正在分发密钥与配置至 ${host} ---"
    ssh "${USER_NAME}@${host}" "mkdir -p ${SSH_DIR} && chmod 700 ${SSH_DIR}" || true
    scp "${SSH_DIR}/authorized_keys" "${USER_NAME}@${host}:${SSH_DIR}/authorized_keys" || true
    scp "${SSH_DIR}/id_rsa" "${USER_NAME}@${host}:${SSH_DIR}/id_rsa" || true
    scp "${SSH_DIR}/id_rsa.pub" "${USER_NAME}@${host}:${SSH_DIR}/id_rsa.pub" || true
    scp "${SSH_DIR}/config" "${USER_NAME}@${host}:${SSH_DIR}/config" || true
    ssh "${USER_NAME}@${host}" "chmod 600 ${SSH_DIR}/authorized_keys ${SSH_DIR}/id_rsa ${SSH_DIR}/config" || true
done

echo ">>> [4/4] 验证 6 节点免密连通性 (如 PDF 第 5 页脚本)..."
for host in "${HOSTS[@]}"; do
    echo -n "测试连接到 ${host}: "
    ssh "${USER_NAME}@${host}" "hostname"
done

echo "=========================================================="
echo "6 节点 SSH 互信及免交互配置全部成功！"
echo "=========================================================="
