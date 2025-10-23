#!/bin/bash
set -euo pipefail

# 读取 Terraform 传参
SPARK_VERSION="${spark_version}"
SPARK_USER="${spark_user}"

echo "==== Step 1: 更新系统包 ===="
apt-get update -y
echo "==== 系统包更新完成 ===="

echo "==== Step 2: 安装依赖 ===="
apt-get install -y openjdk-11-jdk scala wget curl git
echo "==== 依赖安装完成 ===="

echo "==== Step 3: 创建 Spark 用户 ===="
if ! id "$SPARK_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$SPARK_USER"
  echo "==== Spark 用户 $SPARK_USER 已创建 ===="
else
  echo "==== Spark 用户 $SPARK_USER 已存在 ===="
fi

echo "==== Step 4: 下载并解压 Spark ===="
SPARK_DIR="/opt/spark"
SPARK_TGZ="spark-${SPARK_VERSION}-bin-hadoop3.tgz"
SPARK_URL="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}"

wget -q "$SPARK_URL" -O "/tmp/${SPARK_TGZ}"
tar -xf "/tmp/${SPARK_TGZ}" -C /opt
mv "/opt/spark-${SPARK_VERSION}-bin-hadoop3" "$SPARK_DIR"
chown -R "$SPARK_USER:$SPARK_USER" "$SPARK_DIR"
echo "==== Spark 解压并授权完成 ===="

echo "==== Step 5: 配置环境变量 ===="
cat >/etc/profile.d/spark.sh <<EOF
export SPARK_HOME=$SPARK_DIR
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
export PYSPARK_PYTHON=/usr/bin/python3
EOF
source /etc/profile.d/spark.sh
echo "==== Spark 环境变量已写入 /etc/profile.d/spark.sh ===="

echo "==== Step 6: 配置 Spark 默认环境 ===="
cat >"$SPARK_DIR/conf/spark-env.sh" <<EOF
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_MASTER_HOST=\$(hostname -I | awk '{print \$1}')
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080
EOF
chown "$SPARK_USER:$SPARK_USER" "$SPARK_DIR/conf/spark-env.sh"
echo "==== spark-env.sh 已生成 ===="

echo "==== Step 7: 配置 Spark Default Settings ===="
cat >"$SPARK_DIR/conf/spark-defaults.conf" <<EOF
spark.master                     spark://\$(hostname -I | awk '{print \$1}'):7077
spark.eventLog.enabled           true
spark.eventLog.dir               /tmp/spark-events
spark.history.fs.logDirectory    /tmp/spark-events
EOF
chown "$SPARK_USER:$SPARK_USER" "$SPARK_DIR/conf/spark-defaults.conf"
echo "==== spark-defaults.conf 已生成 ===="

echo "==== Step 8: 创建 Spark 事件目录 ===="
mkdir -p /tmp/spark-events
chown "$SPARK_USER:$SPARK_USER" /tmp/spark-events
echo "==== 事件目录已创建并授权 ===="

echo "==== Step 9: 配置 systemd 服务 ===="
cat >/etc/systemd/system/spark-master.service <<EOF
[Unit]
Description=Apache Spark Master
After=network.target

[Service]
Type=forking
User=$SPARK_USER
Group=$SPARK_USER
ExecStart=$SPARK_DIR/sbin/start-master.sh
ExecStop=$SPARK_DIR/sbin/stop-master.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/spark-worker.service <<EOF
[Unit]
Description=Apache Spark Worker
After=network.target

[Service]
Type=forking
User=$SPARK_USER
Group=$SPARK_USER
ExecStart=$SPARK_DIR/sbin/start-worker.sh spark://\$(hostname -I | awk '{print \$1}'):7077
ExecStop=$SPARK_DIR/sbin/stop-worker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable spark-master spark-worker
systemctl start spark-master
systemctl start spark-worker
echo "==== Spark Master & Worker 服务已启动 ===="

echo "==== Step 10: 验证启动 ===="
systemctl status spark-master spark-worker --no-pager || true
echo "==== Spark 单节点集群安装完成 ===="