#!/bin/bash
set -e  # 出错时终止脚本

# 安装依赖（SSH服务、Java）
apt update -y && apt upgrade -y
apt install -y openssh-server openjdk-11-jdk

# 配置SSH免密登录（Spark内部通信需要）
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 下载并安装Spark 3.5.0（兼容Hadoop 3）
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3"
SPARK_TAR="spark-\${SPARK_VERSION}-bin-hadoop\${HADOOP_VERSION}.tgz"
wget "https://archive.apache.org/dist/spark/spark-\${SPARK_VERSION}/\${SPARK_TAR}" -P /tmp
tar xzf /tmp/\${SPARK_TAR} -C /opt
ln -s /opt/spark-\${SPARK_VERSION}-bin-hadoop\${HADOOP_VERSION} /opt/spark

# 配置环境变量
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /etc/profile
echo "export SPARK_HOME=/opt/spark" >> /etc/profile
echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> /etc/profile
source /etc/profile

# 配置Spark Master（绑定到虚拟机内部IP）
INTERNAL_IP=\$(hostname -I | awk '{print \$1}')  # 获取内部IP
cp /opt/spark/conf/spark-env.sh.template /opt/spark/conf/spark-env.sh
echo "export SPARK_MASTER_HOST=\${INTERNAL_IP}" >> /opt/spark/conf/spark-env.sh
echo "export SPARK_WORKER_CORES=2" >> /opt/spark/conf/spark-env.sh  # 分配2核
echo "export SPARK_WORKER_MEMORY=4g" >> /opt/spark/conf/spark-env.sh  # 分配4GB内存

# 启动Spark（Master+Worker）
/opt/spark/sbin/start-all.sh