#!/usr/bin/env bash
# ==============================================================================
# 生产级上线前置检查脚本 (Pre-flight Validation)
# 作用：在正式执行部署前，全自动体检所有主机的硬件、网络、时钟与端口环境
# ==============================================================================

set -e

BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE_DIR"

echo "================================================================================"
echo ">>> 开始执行大数据集群生产上线前置检查 (Pre-flight Check)..."
echo "================================================================================"

INVENTORY_FILE="${1:-inventory/hosts.yml}"
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "[-] 错误：未找到主机清单文件 $INVENTORY_FILE"
    exit 1
fi

HOSTS=$(ansible all_nodes -i "$INVENTORY_FILE" --list-hosts 2>/dev/null | tail -n +2 | tr -d ' ' | sort -u)

echo "[1/6] 检查控制机 Ansible 连通性..."
ansible all_nodes -i "$INVENTORY_FILE" -m ping > /dev/null 2>&1 && echo "  [✔] 全节点 SSH 免密与 Ansible 连通性正常" || {
    echo "  [✘] 严重错误：部分节点 Ansible Ping 失败，请检查 hosts.yml 与 SSH 免密！"
    ansible all_nodes -i "$INVENTORY_FILE" -m ping
    exit 1
}

echo "[2/6] 检查 packages 目录离线安装包完整性..."
PACKAGES=(
    "jdk-8u202-linux-x64.tar.gz"
    "scala-2.11.12.tgz"
    "apache-zookeeper-3.8.4-bin.tar.gz"
    "hadoop-2.10.1.tar.gz"
    "spark-2.4.8-bin-hadoop2.7.tgz"
)
PKG_MISSING=0
for pkg in "${PACKAGES[@]}"; do
    if [ -f "packages/$pkg" ]; then
        SIZE=$(du -h "packages/$pkg" | awk '{print $1}')
        echo "  [✔] 离线包存在: $pkg ($SIZE)"
    else
        echo "  [!] 缺失安装包: packages/$pkg (可运行 scripts/download_packages.sh 下载)"
        PKG_MISSING=1
    fi
done

if [ $PKG_MISSING -eq 1 ]; then
    echo "  [WARN] 警告：执行一键部署前需确保 packages 目录下安装包齐全！"
fi

echo "[3/6] 检查各节点磁盘剩余空间 (推荐根目录或数据盘 >= 20GB)..."
for h in $HOSTS; do
    disk=$(ssh -o ConnectTimeout=3 $h "df -h / | awk 'NR==2 {print \$4}'" 2>/dev/null || echo "Unknown")
    echo "  [*] $h 根分区可用空间: $disk"
done

echo "[4/6] 检查各节点系统内存容量..."
for h in $HOSTS; do
    mem=$(ssh -o ConnectTimeout=3 $h "free -h | awk 'NR==2 {print \"总量: \" \$2 \", 可用: \" \$7}'" 2>/dev/null || echo "Unknown")
    echo "  [*] $h 内存 $mem"
done

echo "[5/6] 检查分布式关键端口占用情况 (2181, 9000, 50070, 8088, 8485, 18080)..."
for h in $HOSTS; do
    portinfo=$(ssh -o ConnectTimeout=3 $h "ss -tulpn | grep -E ':(2181|9000|50070|8088|8485|18080)\b' | awk '{print \$5}' | sort -u | tr '\n' ' '" 2>/dev/null || true)
    if [ -n "$portinfo" ]; then
        echo "  [!] $h 监听中端口: $portinfo (若为集群已有组件则正常)"
    else
        echo "  [✔] $h 核心大数据端口均空闲可用"
    fi
done

echo "[6/6] 检查系统时钟服务 (Chrony / NTP 时钟漂移检查)..."
for h in $HOSTS; do
    clk=$(ssh -o ConnectTimeout=3 $h "systemctl is-active chronyd 2>/dev/null || systemctl is-active ntpd 2>/dev/null || echo 'inactive'" 2>/dev/null || echo "offline")
    if [ "$clk" = "active" ]; then
        echo "  [✔] $h 时钟同步服务正常运行 (active)"
    else
        echo "  [!] $h 时钟同步服务未运行 ($clk)，剧本 00-system-init.yml 会自动配置并启动"
    fi
done

echo "================================================================================"
echo ">>> 前置体检执行完毕！若无阻断性错误，即可放心执行 ansible-playbook playbooks/site.yml"
echo "================================================================================"
