#!/bin/bash
set -euo pipefail

# >>> 1. 日志文件路径（只落盘，不回显）
LOG_FILE="/var/log/install-spark.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > "$LOG_FILE" 2>&1

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

# 预解析Master主机IP（避免systemd环境变量解析失败）
SPARK_MASTER_HOST=$(hostname -I | awk '{print $1}')
echo "==== 预解析Master主机IP为 ${SPARK_MASTER_HOST} ===="

echo "==== Step 6: 配置 Spark 默认环境（关键修复） ===="
cat >/opt/spark/conf/spark-env.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_MASTER_HOST=$SPARK_MASTER_HOST  # Master主机地址（静态化后的值）
export SPARK_MASTER_PORT=7077                             # Master端口
export SPARK_MASTER_WEBUI_PORT=8080                       # Master WebUI端口
export SPARK_MASTER_URL=spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT}  # 统一Master URL
EOF
chown spark:spark /opt/spark/conf/spark-env.sh
echo "==== spark-env.sh 已生成（包含静态Master IP和URL变量） ===="

echo "==== Step 7: 配置 Spark Default Settings（清理冗余） ===="
cat >/opt/spark/conf/spark-defaults.conf <<'EOF'
spark.eventLog.enabled           true
spark.eventLog.dir               /tmp/spark-events
spark.history.fs.logDirectory    /tmp/spark-events
EOF
chown spark:spark /opt/spark/conf/spark-defaults.conf
echo "==== spark-defaults.conf 已生成（移除冗余Master配置） ===="

echo "==== Step 8: 创建 Spark 事件目录 ===="
mkdir -p /tmp/spark-events
chown spark:spark /tmp/spark-events
echo "==== 事件目录已创建并授权 ===="

echo "==== Step 9: 配置 systemd 服务（关键修复） ===="
# Master 服务
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

# Worker 服务（修改Type为forking，适配Spark后台启动逻辑）
cat >/etc/systemd/system/spark-worker.service <<'EOF'
[Unit]
Description=Apache Spark Worker
After=network.target spark-master.service  # 依赖Master服务，确保Master先启动

[Service]
Type=forking  # 改为forking，适配Spark后台启动脚本的运行机制
User=spark
Group=spark
Restart=always
RestartSec=5
EnvironmentFile=/opt/spark/conf/spark-env.sh  # 加载环境变量
ExecStart=/opt/spark/sbin/start-worker.sh $SPARK_MASTER_URL  # 引用预定义的Master URL
ExecStop=/opt/spark/sbin/stop-worker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spark-master spark-worker
systemctl restart spark-master spark-worker
echo "==== Spark Master & Worker 服务已启动 ===="

echo "==== Step 10: 验证启动（增强验证） ===="
echo "==== 服务状态检查 ===="
systemctl status spark-master spark-worker --no-pager || true

echo "==== 集群连通性测试 ===="
# 以spark用户执行简单的Spark任务，验证集群可用性
su - spark -c "spark-shell --master \$SPARK_MASTER_URL --executor-memory 512M --total-executor-cores 1 -e 'println(\"Spark集群连接成功！\"); sys.exit(0)'" || {
  echo "==== 集群连通性测试失败，请检查日志 ===="
  exit 1
}

echo "==== Spark 单节点集群安装完成 ===="
echo "======== $(date '+%F %T') install-spark.sh 执行结束 ========"