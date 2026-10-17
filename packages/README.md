# 离线安装包存放目录 (Offline Packages Directory)

本目录用于存放集群部署所需的离线二进制 `.tar.gz` / `.tgz` 安装包。由于安装包体积较大（超过 GitHub 100MB 限制），`.gitignore` 已默认将压缩包过滤，不会提交到 Git 仓库。

---

## 需准备的 5 个二进制包列表

请将以下 5 个文件放置在本 `packages/` 目录下（文件名需严格一致）：

| 序号 | 软件名称 | 官方/标准文件名 | 建议版本 | 校验说明 / 默认安装路径 |
|:---:|---|---|:---:|---|
| 1 | **Oracle JDK** | `jdk-8u202-linux-x64.tar.gz` | `8u202` | 解压至 `/home/software/jdk1.8.0_202` |
| 2 | **Scala** | `scala-2.11.12.tgz` | `2.11.12` | 解压至 `/home/software/scala-2.11.12` |
| 3 | **Apache ZooKeeper** | `apache-zookeeper-3.8.4-bin.tar.gz` | `3.8.4` | **注意必须是 -bin.tar.gz**，解压至 `/usr/local/apache-zookeeper-3.8.4-bin` |
| 4 | **Apache Hadoop** | `hadoop-2.10.1.tar.gz` | `2.10.1` | 解压至 `/home/software/hadoop-2.10.1` |
| 5 | **Apache Spark** | `spark-2.4.8-bin-hadoop2.7.tgz` | `2.4.8` | 解压至 `/home/software/spark-2.4.8-bin-hadoop2.7` |

---

## 离线包获取途径

1. **自动下载（如果在有外网的控制机执行）**：
   运行项目根目录下的脚本：
   ```bash
   bash scripts/download_packages.sh
   ```
2. **官方镜像归档下载**：
   - Hadoop 2.10.1: https://archive.apache.org/dist/hadoop/common/hadoop-2.10.1/hadoop-2.10.1.tar.gz
   - ZooKeeper 3.8.4: https://archive.apache.org/dist/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz
   - Spark 2.4.8: https://archive.apache.org/dist/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz
   - Scala 2.11.12: https://downloads.lightbend.com/scala/2.11.12/scala-2.11.12.tgz
   - JDK 8u202: https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz （或 Oracle 官网 Java Archive）
