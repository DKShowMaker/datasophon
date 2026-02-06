#!/bin/bash
MINIO_HOME="${minioInstallPath}/minio"
# 设置MinIO的配置参数
export MINIO_ROOT_USER=${MINIO_ACCESS_KEY}
export MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}
export MINIO_CI_CD=on # 打开调试模式可以不必单独挂载磁盘
export MINIO_PROMETHEUS_AUTH_TYPE=public   #加入这行环境变量，“public”表示Prometheus访问minio集群可以不通过身份验证

$MINIO_HOME/minio server --config-dir $MINIO_HOME/etc \
        --address "0.0.0.0:${apiPort}" --console-address ":${consolePort}" \
        ${dataPaths} > $MINIO_HOME/minio.log 2>&1 &
