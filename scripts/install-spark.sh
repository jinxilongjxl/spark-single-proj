#!/bin/bash
set -euo pipefail

# >>> 1. 日志文件路径（只落盘，不回显）
LOG_FILE="/var/log/install-spark.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > "$LOG_FILE" 2>&1          # <<< 关键变更：去掉tee，终端不再回显

# >>> 2. 打时间戳
echo "======== $(date '+%F %T') install-spark.sh 开始执行 ========"

echo "==== Step 1: 更新系统包 ===="
apt-get update -y
echo "==== 系统包更新完成 ===="

echo "==== Step 2: 安装依赖 ===="
apt-get install -y openjdk-11-jdk scala wget curl git
echo "==== 依赖安装完成 ===="

echo "==== Step 3: 创建 Spark 用户 ===="
if ! id "spark" &>/dev/null; then
  useradd -m -s /bin/bash spark
  echo "==== Spark 用户 spark 已创建 ===="
else
  echo "==== Spark 用户 spark 已存在 ===="
fi

echo "==== Step 4: 下载并解压 Spark ===="
wget -q https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz -O /tmp/spark-3.5.1-bin-hadoop3.tgz
tar -xf /tmp/spark-3.5.1-bin-hadoop3.tgz -C /opt
mv /opt/spark-3.5.1-bin-hadoop3 /opt/spark
chown -R spark:spark /opt/spark
echo "==== Spark 解压并授权完成 ===="

echo "==== Step 5: 配置环境变量 ===="
cat >/etc/profile.d/spark.sh <<'EOF'
export SPARK_HOME=/opt/spark
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
export PYSPARK_PYTHON=/usr/bin/python3
EOF
source /etc/profile.d/spark.sh
echo "==== Spark 环境变量已写入 /etc/profile.d/spark.sh ===="

echo "==== Step 6: 配置 Spark 默认环境 ===="
cat >/opt/spark/conf/spark-env.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_MASTER_HOST=$(hostname -I | awk '{print $1}')
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080
EOF
chown spark:spark /opt/spark/conf/spark-env.sh
echo "==== spark-env.sh 已生成 ===="

echo "==== Step 7: 配置 Spark Default Settings ===="
cat >/opt/spark/conf/spark-defaults.conf <<'EOF'
spark.master                     spark://$(hostname -I | awk '{print $1}'):7077
spark.eventLog.enabled           true
spark.eventLog.dir               /tmp/spark-events
spark.history.fs.logDirectory    /tmp/spark-events
EOF
chown spark:spark /opt/spark/conf/spark-defaults.conf
echo "==== spark-defaults.conf 已生成 ===="

echo "==== Step 8: 创建 Spark 事件目录 ===="
mkdir -p /tmp/spark-events
chown spark:spark /tmp/spark-events
echo "==== 事件目录已创建并授权 ===="

echo "==== Step 9: 配置 systemd 服务 ===="
# Master 服务（简单模式，防闪退）
cat >/etc/systemd/system/spark-master.service <<'EOF'
[Unit]
Description=Apache Spark Master
After=network.target

[Service]
Type=simple
User=spark
Group=spark
Restart=always
RestartSec=5
ExecStart=/opt/spark/sbin/start-master.sh
ExecStop=/opt/spark/sbin/stop-master.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Worker 服务（simple + 内网地址）
cat >/etc/systemd/system/spark-worker.service <<'EOF'
[Unit]
Description=Apache Spark Worker
After=network.target

[Service]
Type=simple
User=spark
Group=spark
Restart=always
RestartSec=5
ExecStart=/opt/spark/sbin/start-worker.sh spark://$(hostname -I | awk '{print $1}'):7077
ExecStop=/opt/spark/sbin/stop-worker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spark-master spark-worker
systemctl restart spark-master spark-worker
echo "==== Spark Master & Worker 服务已启动 ===="

echo "==== Step 10: 验证启动 ===="
systemctl status spark-master spark-worker --no-pager || true
echo "==== Spark 单节点集群安装完成 ===="

echo "======== $(date '+%F %T') install-spark.sh 执行结束 ========"