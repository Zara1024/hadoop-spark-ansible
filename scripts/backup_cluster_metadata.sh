#!/usr/bin/env bash
# ==============================================================================
# 生产级元数据灾备与容灾备份脚本 (Metadata Backup & Disaster Recovery)
# 作用：定时保存并归档 HDFS NameNode fsimage/edits 及 ZooKeeper 事务快照
# 生产建议：配置于 crontab 中每日凌晨自动执行，如 0 2 * * * /root/hadoop-spark-ansible/scripts/backup_cluster_metadata.sh
# ==============================================================================

set -e

BACKUP_ROOT="/home/backup/bigdata"
DATE_STR=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${DATE_STR}"
mkdir -p "${BACKUP_DIR}"

echo ">>> 开始执行大数据核心元数据灾备任务: ${DATE_STR}"

# 1. 触发 HDFS NameNode 保存最新命名空间快照 (SaveNamespace)
echo "[1/3] 刷新 HDFS NameNode 元数据快照 (fsimage)..."
source /etc/profile
if hdfs haadmin -getServiceState nn1 2>/dev/null | grep -q "active"; then
    hdfs dfsadmin -saveNamespace || echo "  [WARN] saveNamespace 提示安全模式限制，直接读取落盘文件"
fi

# 2. 备份 NameNode 元数据目录
NN_DIR="/home/software/hadoop-2.10.1/tmp/namenode"
if [ -d "$NN_DIR" ]; then
    echo "[2/3] 打包归档 NameNode 元数据目录 ($NN_DIR)..."
    tar -czf "${BACKUP_DIR}/hadoop_namenode_meta_${DATE_STR}.tar.gz" -C "$(dirname $NN_DIR)" "$(basename $NN_DIR)"
    echo "  [✔] NameNode 元数据备份完毕: ${BACKUP_DIR}/hadoop_namenode_meta_${DATE_STR}.tar.gz"
fi

# 3. 备份 ZooKeeper 数据与快照目录
ZK_DIR="/usr/local/apache-zookeeper-3.8.4-bin/data"
if [ -d "$ZK_DIR" ]; then
    echo "[3/3] 打包归档 ZooKeeper 快照目录 ($ZK_DIR)..."
    tar -czf "${BACKUP_DIR}/zookeeper_data_${DATE_STR}.tar.gz" -C "$(dirname $ZK_DIR)" "$(basename $ZK_DIR)"
    echo "  [✔] ZooKeeper 元数据备份完毕: ${BACKUP_DIR}/zookeeper_data_${DATE_STR}.tar.gz"
fi

# 4. 清理超过 14 天的历史备份，防止打满磁盘
echo "[-] 自动清理超过 14 天的过期备份..."
find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} + 2>/dev/null || true

echo ">>> 元数据灾备全量完成！备份存放位置: ${BACKUP_DIR}"
ls -lh "${BACKUP_DIR}"
