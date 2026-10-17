#!/bin/bash
# ==============================================================================
# 集群服务健康度巡检脚本 (比对 PDF 第 27 页进程表)
# ==============================================================================

HOSTS=("spark01" "spark02" "spark03" "spark04" "spark05" "spark06")

echo "=========================================================="
echo "          Hadoop + Spark + ZooKeeper 进程巡检             "
echo "=========================================================="

for host in "${HOSTS[@]}"; do
    echo "----------------------------------------------------------"
    echo "主机: ${host}"
    echo "----------------------------------------------------------"
    ssh -o StrictHostKeyChecking=no "root@${host}" "/home/software/jdk1.8.0_202/bin/jps 2>/dev/null || jps"
    echo ""
done

echo "=========================================================="
echo "          Web 端口可用性检查                              "
echo "=========================================================="
echo -n "spark01 NameNode Web (http://spark01:50070): "
curl -s -m 3 -I http://spark01:50070 | head -n 1 || echo "无法访问"

echo -n "spark02 NameNode Web (http://spark02:50070): "
curl -s -m 3 -I http://spark02:50070 | head -n 1 || echo "无法访问"

echo -n "spark01 YARN RM Web (http://spark01:8088): "
curl -s -m 3 -I http://spark01:8088 | head -n 1 || echo "无法访问"

echo -n "spark03 YARN RM Web (http://spark03:8088): "
curl -s -m 3 -I http://spark03:8088 | head -n 1 || echo "无法访问"

echo -n "spark06 Spark History Server (http://spark06:18080): "
curl -s -m 3 -I http://spark06:18080 | head -n 1 || echo "无法访问"

echo "=========================================================="
echo "巡检完成！"
echo "=========================================================="
