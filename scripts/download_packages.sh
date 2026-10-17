#!/bin/bash
# ==============================================================================
# 离线安装包辅助下载脚本 (供在有外网连接的环境下准备安装包使用)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/../packages"

mkdir -p "${PACKAGES_DIR}"
cd "${PACKAGES_DIR}"

echo "=========================================================="
echo "准备下载 Hadoop + Spark + ZooKeeper 离线安装包到: ${PACKAGES_DIR}"
echo "=========================================================="

# 1. ZooKeeper 3.8.4
if [ ! -f "apache-zookeeper-3.8.4-bin.tar.gz" ]; then
    echo ">>> [1/5] 正在下载 Apache ZooKeeper 3.8.4..."
    curl -fSL -C - "https://archive.apache.org/dist/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz" -o "apache-zookeeper-3.8.4-bin.tar.gz"
else
    echo ">>> [1/5] apache-zookeeper-3.8.4-bin.tar.gz 已存在，跳过下载。"
fi

# 2. Hadoop 2.10.1
if [ ! -f "hadoop-2.10.1.tar.gz" ]; then
    echo ">>> [2/5] 正在下载 Apache Hadoop 2.10.1..."
    curl -fSL -C - "https://archive.apache.org/dist/hadoop/common/hadoop-2.10.1/hadoop-2.10.1.tar.gz" -o "hadoop-2.10.1.tar.gz"
else
    echo ">>> [2/5] hadoop-2.10.1.tar.gz 已存在，跳过下载。"
fi

# 3. Scala 2.11.12
if [ ! -f "scala-2.11.12.tgz" ]; then
    echo ">>> [3/5] 正在下载 Scala 2.11.12..."
    curl -fSL -C - "https://www.scala-lang.org/files/archive/scala-2.11.12.tgz" -o "scala-2.11.12.tgz"
else
    echo ">>> [3/5] scala-2.11.12.tgz 已存在，跳过下载。"
fi

# 4. Spark 2.4.8 (Hadoop 2.7 build)
if [ ! -f "spark-2.4.8-bin-hadoop2.7.tgz" ]; then
    echo ">>> [4/5] 正在下载 Apache Spark 2.4.8..."
    curl -fSL -C - "https://archive.apache.org/dist/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz" -o "spark-2.4.8-bin-hadoop2.7.tgz"
else
    echo ">>> [4/5] spark-2.4.8-bin-hadoop2.7.tgz 已存在，跳过下载。"
fi

# 5. Oracle JDK 8u202
if [ ! -f "jdk-8u202-linux-x64.tar.gz" ]; then
    echo ">>> [5/5] 正在下载 Oracle JDK 8u202 (华为云镜像)..."
    curl -fSL -C - "https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz" -o "jdk-8u202-linux-x64.tar.gz"
else
    echo ">>> [5/5] jdk-8u202-linux-x64.tar.gz 已存在，跳过下载。"
fi

echo "=========================================================="
echo "离线包下载/检查完成！当前 packages 目录内容："
ls -lh "${PACKAGES_DIR}"
echo "=========================================================="
