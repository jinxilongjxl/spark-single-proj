#!/bin/bash
set -e  # 出错时终止脚本

# 初始提示
echo -e "\n===== 开始安装 Spark 4.0.1 环境 ====="
echo "当前时间: $(date)"


# 1. 更新系统并安装依赖
echo -e "\n===== 步骤1/8：更新系统并安装基础依赖 ====="
echo "正在更新系统包索引..."
apt update -y > /dev/null  # 静默执行，仅通过echo提示进度
echo "系统包索引更新完成，开始升级系统组件..."
apt upgrade -y > /dev/null
echo "系统升级完成，开始安装 SSH 服务和 Java 11..."
apt install -y openssh-server openjdk-11-jdk > /dev/null
echo "依赖安装完成：已安装 SSH 服务和 Java 11"
echo "Java 版本验证：$(java -version 2>&1 | head -n1)"  # 输出Java版本


# 2. 创建单独的spark用户和组
echo -e "\n===== 步骤2/8：创建专用 spark 用户和组 ====="
echo "正在创建 spark 组..."
groupadd -r spark > /dev/null
echo "spark 组创建完成，正在创建 spark 用户（家目录：/home/spark）..."
useradd -r -g spark -m -d /home/spark -s /bin/bash spark > /dev/null
echo "spark 用户创建成功，用户信息：$(id spark)"  # 输出用户ID和组信息


# 3. 为spark用户配置SSH免密登录
echo -e "\n===== 步骤3/8：配置 spark 用户 SSH 免密登录 ====="
echo "正在为 spark 用户生成 SSH 密钥对（无密码）..."
sudo -u spark bash -c '
  ssh-keygen -t rsa -P "" -f /home/spark/.ssh/id_rsa > /dev/null 2>&1
  cat /home/spark/.ssh/id_rsa.pub >> /home/spark/.ssh/authorized_keys
  chmod 600 /home/spark/.ssh/authorized_keys
'
echo "SSH 密钥配置完成，正在重启 SSH 服务..."
systemctl enable ssh > /dev/null
systemctl restart ssh > /dev/null
echo "SSH 服务已启动，状态：$(systemctl is-active ssh)"  # 输出服务状态


# 4. 下载并安装Spark 4.0.1
echo -e "\n===== 步骤4/8：下载并安装 Spark 4.0.1 ====="
SPARK_VERSION="4.0.1"
HADOOP_VERSION="3"
SPARK_TAR="spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
SPARK_URL="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_TAR}"

echo "当前安装版本：Spark ${SPARK_VERSION}（兼容 Hadoop ${HADOOP_VERSION}）"
echo "下载地址：${SPARK_URL}"
echo "开始下载 Spark 安装包（可能需要几分钟，取决于网络速度）..."
wget -q --show-progress -O /tmp/${SPARK_TAR} ${SPARK_URL} || {
  echo "ERROR: Spark 安装包下载失败，请检查 URL 是否有效"
  exit 1
}
echo "Spark 安装包下载完成（/tmp/${SPARK_TAR}）"

echo "正在解压安装包到 /opt 目录..."
tar xzf /tmp/${SPARK_TAR} -C /opt > /dev/null
echo "解压完成，创建软链接 /opt/spark -> /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}..."
ln -s /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark > /dev/null
echo "设置权限：将 Spark 目录归属 spark 用户..."
chown -R spark:spark /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark > /dev/null
echo "清理临时文件：删除 /tmp/${SPARK_TAR}..."
rm -f /tmp/${SPARK_TAR}
echo "Spark 安装完成，目录：/opt/spark"


# 5. 为spark用户配置环境变量
echo -e "\n===== 步骤5/8：配置 spark 用户环境变量 ====="
echo "正在向 /home/spark/.bashrc 写入环境变量（JAVA_HOME、SPARK_HOME）..."
sudo -u spark bash -c '
  cat << EOF >> /home/spark/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_HOME=/opt/spark
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
EOF
'
echo "环境变量配置完成，验证是否生效..."
sudo -u spark bash -c 'source /home/spark/.bashrc && echo "SPARK_HOME 已设置：\$SPARK_HOME"'  # 验证变量


# 6. 配置Spark参数（绑定内部IP）
echo -e "\n===== 步骤6/8：配置 Spark 核心参数 ====="
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo "获取虚拟机内部IP：${INTERNAL_IP}（用于绑定 Spark Master）"
echo "正在配置 spark-env.sh（Worker 核心数、内存、运行用户）..."
sudo -u spark bash -c "
  cp /opt/spark/conf/spark-env.sh.template /opt/spark/conf/spark-env.sh > /dev/null
  cat << EOF >> /opt/spark/conf/spark-env.sh
export SPARK_MASTER_HOST=${INTERNAL_IP}
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=4g
export SPARK_USER=spark
EOF
"
echo "Spark 参数配置完成，配置文件：/opt/spark/conf/spark-env.sh"


# 7. 切换到spark用户启动Spark
echo -e "\n===== 步骤7/8：启动 Spark 服务（Master + Worker） ====="
echo "切换到 spark 用户，加载环境变量并启动服务..."
sudo -u spark bash -c '
  source /home/spark/.bashrc
  /opt/spark/sbin/start-all.sh > /dev/null 2>&1
'
echo "Spark 服务启动完成（后台运行）"


# 8. 验证启动状态
echo -e "\n===== 步骤8/8：验证 Spark 启动状态 ====="
echo "检查 Spark 进程（应为 spark 用户运行）："
PROCESS_OUTPUT=$(ps -ef | grep -E "spark[/-]master|spark[/-]worker" | grep -v grep)
if [ -n "$PROCESS_OUTPUT" ]; then
  echo "$PROCESS_OUTPUT"
  echo -e "\n===== Spark 4.0.1 环境安装成功！ ====="
  echo "Spark Master Web UI：http://$(curl -s ifconfig.me):8080"
else
  echo "ERROR: 未检测到 Spark 进程，启动失败"
  exit 1
fi