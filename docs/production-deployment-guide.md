# Hadoop HA + Spark on YARN + ZooKeeper 生产级部署与落地运维实战指南

> **适用场景**：金融、政企、互联网中大型生产环境的大数据基础平台标准化交付与长期运维。  
> **设计目标**：高可用（零单点）、高性能（低 GC 延迟）、高可靠（数据多副本与元数据灾备）、免维护（自动轮转与自愈监控）。

---

## 一、生产环境硬件规格与角色规划标准

生产环境严禁将所有主备服务混跑在低配机器上。推荐采用物理机或企业级高配云主机，标准配置推荐如下：

| 节点规划 | 推荐硬件规格 | 推荐磁盘配置 | 运行组件规划 | 职责说明 |
| :--- | :--- | :--- | :--- | :--- |
| **Master-01 (spark01)** | 16核 64GB 内存 | 2×系统盘 (RAID1) + 2×SSD (元数据) | ZK-1, NN1 (Active), RM1 (Standby), ZKFC, JobHistory | 主控制、主命名空间与调度备机 |
| **Master-02 (spark02)** | 16核 64GB 内存 | 2×系统盘 (RAID1) + 2×SSD (元数据) | ZK-2, NN2 (Standby), ZKFC | 备命名空间与热备选举节点 |
| **Master-03 (spark03)** | 16核 64GB 内存 | 2×系统盘 (RAID1) + 2×SSD (元数据) | ZK-3, RM2 (Active) | 主资源调度与 ZK 选举仲裁者 |
| **Worker-01~N (spark04~N)**| 32核 128GB~256GB 内存 | 2×系统盘 + 12×4TB/8TB SATA (JBOD模式) | JN, DataNode, NodeManager, Spark Client | 核心存储与分布式算力池 |
| **专用边缘机 (spark06 或独立)** | 8核 32GB 内存 | 2×系统盘 (RAID1) | Spark History Server, Hive Metastore | 日志聚合与历史归档服务 |

---

## 二、生产核心调优参数（如何切换生产模式）

在生产环境部署时，打开 `inventory/group_vars/all.yml`，调整以下生产参数：

### 1. 内存池与算力调度参数切换（对齐 PDF 第 9 节）

```yaml
# ==================== YARN 生产规格配置 ====================
yarn_pmem_check_enabled: "false"      # 生产建议关闭物理内存硬杀，防止突发流量中断任务
yarn_vmem_check_enabled: "false"      # 关闭虚拟内存检查
yarn_vmem_pmem_ratio: 2.1             # 生产标准比例

# 单台 Worker 节点算力分配 (以 32核 128GB 机器为例，保留 32GB 给系统、DataNode 与缓存)：
yarn_nodemanager_resource_cpu_vcores: 24       # 分配 24 物理核心
yarn_nodemanager_resource_memory_mb: 98304     # 分配 96 GB (96 * 1024)
yarn_scheduler_min_vcores: 1
yarn_scheduler_max_vcores: 24
yarn_scheduler_min_mb: 1024                   # 最小 Container 1GB
yarn_scheduler_max_mb: 32768                  # 最大单个 Container 32GB
```

### 2. 生产级 JVM 堆内存与 G1GC 配置

元数据规模极大时，默认 1GB 堆内存会导致频发 Full GC 甚至 OOM 崩溃。按如下规则规划：
- **NameNode 内存估算公式**：每 100 万个文件/Block 大约消耗 1GB 内存。生产环境推荐初始配置 **8GB~32GB** 并启用 G1 垃圾收集器。

```yaml
# ==================== 生产级 JVM 堆内存规划 ====================
hadoop_namenode_heapsize: "8192m"      # 8GB 堆内存，配合 G1GC 极大降低 STW
hadoop_datanode_heapsize: "4096m"      # 4GB
hadoop_journalnode_heapsize: "2048m"   # 2GB
yarn_rm_heapsize: "8192m"              # 8GB
yarn_nm_heapsize: "4096m"              # 4GB
zk_heapsize: "4g"                      # ZooKeeper 专用 4GB
```

### 3. 多磁盘（JBOD）多挂载点配置

生产 DataNode 严禁单盘写入，需通过逗号分隔多个挂载目录，HDFS 会自动进行负载均衡：

```yaml
# 在 inventory/group_vars/all.yml 中配置：
hadoop_datanode_dir: "file:///data1/hadoop/data,file:///data2/hadoop/data,file:///data3/hadoop/data"
```

---

## 三、生产部署标准执行流程 (SOP)

### 第 1 步：配置主机清单与运行前置体检
```bash
# 1. 修改主机清单 (标准 YAML 格式)
vim inventory/hosts.yml

# 2. 运行生产前置环境体检脚本 (自动检查 CPU、内存、磁盘、端口冲突与时钟对齐)
bash scripts/preflight_check.sh
```

### 第 2 步：一键全量自动化部署
```bash
ansible-playbook playbooks/site.yml
```
剧本会自动执行：
1. 内核参数加固（`vm.swappiness=1`、`fs.file-max=6553600`、禁用透明大页 THP）。
2. Chrony 时钟服务启动与时间锁定（**防止时钟偏差导致 HA 脑裂与选主震荡**）。
3. Logrotate 日志轮转配置（**防止日志打满系统盘**）。
4. ZooKeeper 3 节点仲裁部署。
5. Hadoop HA 安全格式化与双主备纳管。
6. Spark on YARN 客户端与 HDFS Jar 依赖共享缓存初始化。
7. Spark History Server 守护服务注册自启。

### 第 3 步：运行生产冒烟测试
```bash
ansible-playbook playbooks/smoke-test.yml
```

---

## 四、生产运维与容灾保障规范

### 1. 日常集群生命周期管理
不要在各机器手动执行脚本，统一通过控制机调度：
```bash
# 查看全集群组件运行状态与 JPS
ansible-playbook playbooks/cluster-control.yml -e "action=status"

# 优雅启停集群
ansible-playbook playbooks/cluster-control.yml -e "action=start"
ansible-playbook playbooks/cluster-control.yml -e "action=stop"
ansible-playbook playbooks/cluster-control.yml -e "action=restart"
```

### 2. 核心元数据定时灾备 (备份 HDFS 元数据与 ZK 快照)
将工程自带的灾备脚本挂载至控制机 crontab：
```bash
# 编辑定时任务
crontab -e

# 添加每日凌晨 2:00 自动执行快照与多副本备份
0 2 * * * /root/hadoop-spark-ansible/scripts/backup_cluster_metadata.sh >> /var/log/bigdata_backup.log 2>&1
```

### 3. NameNode 主备故障人工应急倒换 SOP
若主 NameNode（spark01）计划内维护，可平滑执行手动主备切换：
```bash
source /etc/profile
# 将 Active 角色平滑迁移至 spark02
hdfs haadmin -failover nn1 nn2

# 查看切换后状态
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2
```

---

## 五、生产常见故障排查手册

| 故障现象 | 根本原因分析 | 标准处理流程 |
| :--- | :--- | :--- |
| **NameNode 两个节点都是 Standby** | ZooKeeper 锁未释放或 ZKFC 进程异常退出 | 1. 检查 ZKFC 进程：`jps \| grep DFSZKFailoverController`<br>2. 检查 ZK 锁：`zkCli.sh ls /hadoop-ha/ns`<br>3. 手动激活：`hdfs haadmin -transitionToActive --forcemanual nn1` |
| **DataNode 启动后立即退出** | `dfs.datanode.data.dir` 中的 `clusterID` 与 NameNode 格式化后的版本不匹配 | 查看日志 `/home/software/hadoop-2.10.1/logs/hadoop-*-datanode-*.log`；若为二次格式化残留，清空 DataNode 存储目录后重启 |
| **YARN Container 任务被强制杀死** | 任务内存突发峰值触发了 YARN 物理内存硬检查 | 确认 `yarn-site.xml` 中的 `yarn.nodemanager.pmem-check-enabled` 为 `false`；或适当上调任务提交时的 `--executor-memory` |
| **Spark 任务提交缓慢** | 每次提交重复向集群分发 200MB 的 Spark 依赖 jars | 检查 `spark-defaults.conf` 是否配置了 `spark.yarn.jars hdfs:///spark_jars/*`；验证 HDFS 上依赖包是否存在 |
| **磁盘空间不足报警** | GC 日志或各组件输出日志持续累积 | 确认 `/etc/logrotate.d/bigdata` 已生效，或运行 `scripts/backup_cluster_metadata.sh` 清理历史冷数据 |
