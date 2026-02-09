## 1. 构建安装包

下载redis tar包 [redis-7.0.15.tar.gz](https://redis.io/downloads/)      下载[redis-exporter-1.80.2](https://github.com/oliver006/redis_exporter)

```shell
tar -zxvf redis-7.0.15.tar.gz
cd redis-7.0.15
# 编译 如果三台机器的glibc版本不同需要在版本较低的环境中编译，否则可能会提高glibc的版本
make && make install
# 复制安装路径编译文件
mkdir /opt/soft/redis-7.0.15
cd /opt/soft/redis-7.0.15
cp /usr/local/bin/redis* /opt/soft/redis-7.0.15
rm -rf /usr/local/bin/redis*

# 创建自定义文件及文件夹，目录结构为
/opt/datasophon/redis/
[root@ddp02 redis-7.0.15]# tree
.
|-- bin
|   |-- redis-benchmark
|   |-- redis-check-aof
|   |-- redis-check-rdb
|   |-- redis-cli
|   |-- redis-sentinel
|   |-- redis-server
|   |-- redis-control.sh # redis控制脚本，datasophon安装redis时可以自动创建，也可手动创建
|   |-- redis_exporter
|   `-- redis-exporter-control.sh # redis-exporter控制脚本，datasophon安装redis时可以自动创建，也可手动创建
|-- cluster
|   |-- conf
|   |-- log
|   `-- pid
`-- redis-cluster.sh        # 集群初始化脚本，datasophon安装redis时可以自动创建，也可手动创建


tar czf redis-7.0.15.tar.gz redis-7.0.15
md5sum redis-7.0.15.tar.gz
echo 'd20743bd570ab78efaf0a9aa3b28caf5' > redis-7.0.15.tar.gz.md5
cp ./redis-7.0.15.tar.gz ./redis-7.0.15.tar.gz.md5 /opt/datasophon/DDP/packages/
```

## 2. 元数据文件

### **api节点元数据：**

```shell
cd /opt/apps/datasophon-manager-1.2.1/conf/meta/DDP-1.2.1
mkdir REDIS
cd REDIS
touch service_ddl.json
```

**service_ddl.json：**

```shell
{
  "name": "REDIS",
  "label": "REDIS",
  "description": "交互式数据分析notebook",
  "version": "7.0.15",
  "sortNum": 37,
  "dependencies": [],
  "packageName": "redis-7.0.15.tar.gz",
  "decompressPackageName": "redis-7.0.15",
  "roles": [
    {
      "name": "RedisMaster",
      "label": "RedisMaster",
      "roleType": "master",
      "cardinality": "1+",
      "jmxPort": "9120",
      "metricsPath": "/metrics",
      "logFile": "cluster/log/redis-master.log",
      "startRunner": {
        "timeout": "60",
        "program": "bin/redis-control.sh",
        "args": [
          "start",
          "master"
        ]
      },
      "stopRunner": {
        "timeout": "600",
        "program": "bin/redis-control.sh",
        "args": [
          "stop",
          "master"
        ]
      },
      "statusRunner": {
        "timeout": "60",
        "program": "bin/redis-control.sh",
        "args": [
          "status",
          "master"
        ]
      },
      "restartRunner": {
        "timeout": "120",
        "program": "bin/redis-control.sh",
        "args": [
          "restart",
          "master"
        ]
      }
    },
    {
      "name": "RedisWorker",
      "label": "RedisWorker",
      "roleType": "worker",
      "cardinality": "1+",
      "jmxPort": "9121",
      "metricsPath": "/metrics",
      "logFile": "cluster/log/redis-slave.log",
      "startRunner": {
        "timeout": "60",
        "program": "bin/redis-control.sh",
        "args": [
          "start",
          "slave"
        ]
      },
      "stopRunner": {
        "timeout": "600",
        "program": "bin/redis-control.sh",
        "args": [
          "stop",
          "slave"
        ]
      },
      "statusRunner": {
        "timeout": "60",
        "program": "bin/redis-control.sh",
        "args": [
          "status",
          "slave"
        ]
      },
      "restartRunner": {
        "timeout": "120",
        "program": "bin/redis-control.sh",
        "args": [
          "restart",
          "slave"
        ]
      }
    }
  ],
  "configWriter": {
    "generators": [
      {
        "filename": "redis-control.sh",
        "outputDirectory": "bin",
        "configFormat": "custom",
        "templateName": "redis-control.ftl",
        "includeParams": [
          "redisInstallPath",
          "redisMasterPort",
          "redisSlavePort"
        ]
      },
      {
        "filename": "redis-master.conf",
        "configFormat": "custom",
        "outputDirectory": "cluster/conf",
        "templateName": "redis-master.ftl",
        "includeParams": [
          "redisInstallPath",
          "redisMasterPort",
          "custom.master.conf"
        ]
      },
      {
        "filename": "redis-slave.conf",
        "configFormat": "custom",
        "outputDirectory": "cluster/conf",
        "templateName": "redis-slave.ftl",
        "includeParams": [
          "redisInstallPath",
          "redisSlavePort",
          "custom.slave.conf"
        ]
      },
      {
        "filename": "redis-cluster.sh",
        "configFormat": "custom",
        "outputDirectory": "",
        "templateName": "redis-cluster.ftl",
        "includeParams": [
          "redisInstallPath",
          "redisMasterPort",
          "RedisMasterAddr",
          "RedisSlaveAddr"
        ]
      },
      {
        "filename": "redis-exporter-control.sh",
        "configFormat": "custom",
        "outputDirectory": "bin",
        "templateName": "redis-exporter-control.ftl",
        "includeParams": [
          "redisInstallPath",
          "redisMasterPort",
          "redisSlavePort",
          "redisExporterPortMaster",
          "redisExporterPortWorker"
        ]
      }
    ]
  },
  "parameters": [
    {
      "name": "redisInstallPath",
      "label": "Redis安装路径",
      "description": "Redis安装路径",
      "configType": "map",
      "required": true,
      "type": "input",
      "value": "${INSTALL_PATH}",
      "configurableInWizard": false,
      "hidden": true,
      "defaultValue": "${INSTALL_PATH}"
    },
    {
      "name": "redisMasterPort",
      "label": "master节点端口号",
      "description": "",
      "configType": "map",
      "required": true,
      "type": "input",
      "value": "7000",
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": "7000"
    },
    {
      "name": "redisSlavePort",
      "label": "worker节点端口号",
      "description": "",
      "configType": "map",
      "required": true,
      "type": "input",
      "value": "7001",
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": "7001"
    },
    {
      "name": "redisExporterPortMaster",
      "label": "RedisMaster Exporter端口",
      "description": "RedisMaster 的 redis_exporter 监听端口",
      "configType": "map",
      "required": true,
      "type": "input",
      "value": "9120",
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": "9120"
    },
    {
      "name": "redisExporterPortWorker",
      "label": "RedisWorker Exporter端口",
      "description": "RedisWorker 的 redis_exporter 监听端口",
      "configType": "map",
      "required": true,
      "type": "input",
      "value": "9121",
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": "9121"
    },
    {
      "name": "custom.master.conf",
      "label": "自定义master配置",
      "description": "自定义master配置",
      "configType": "custom",
      "required": false,
      "type": "multipleWithKey",
      "value": [],
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": ""
    },
    {
      "name": "custom.slave.conf",
      "label": "自定义worker配置",
      "description": "自定义worker配置",
      "configType": "custom",
      "required": false,
      "type": "multipleWithKey",
      "value": [],
      "configurableInWizard": true,
      "hidden": false,
      "defaultValue": ""
    },
    {
      "name": "RedisMasterAddr",
      "label": "RedisMasterAddr",
      "description": "",
      "configType": "map",
      "required": false,
      "type": "input",
      "value": "",
      "configurableInWizard": true,
      "hidden": true,
      "defaultValue": ""
    },
    {
      "name": "RedisSlaveAddr",
      "label": "RedisSlaveAddr",
      "description": "",
      "configType": "map",
      "required": false,
      "type": "input",
      "value": "",
      "configurableInWizard": true,
      "hidden": true,
      "defaultValue": ""
    }
  ]
}
```

### **各worker节点元数据：**

```shell
cd /opt/datasophon/datasophon-worker/conf/templates
touch redis-cluster.ftl
touch redis-control.ftl
touch redis-master.ftl
touch redis-slave.ftl
touch redis-exporter-control.ftl
```

**redis-cluster.ftl：**

```shell
#!/bin/bash

# Redis Cluster Auto Setup Script
# Automatically assign Slave nodes using --cluster-replicas 1

# All node addresses (Master and Worker)
ALL_NODES="${RedisMasterAddr} ${RedisSlaveAddr}"

# Redis installation path
REDIS_HOME="${redisInstallPath}/redis"

# Check if all nodes are running
check_all_nodes() {
    echo "Checking if all Redis nodes are running..."
    
    for node in $ALL_NODES; do
        host=$(echo "$node" | cut -d ":" -f 1)
        port=$(echo "$node" | cut -d ":" -f 2)
        
        # Check node status using redis-cli ping
        if ! $REDIS_HOME/bin/redis-cli -h $host -p $port ping > /dev/null 2>&1; then
            echo "Redis node $node is not running."
            return 1
        fi
        echo "Redis node $node is running."
    done
    
    return 0
}

# Create cluster (auto-assign Slave)
create_cluster() {
    echo "Creating Redis Cluster with auto-assigned slaves..."
    echo "Nodes: $ALL_NODES"
    
    # Calculate --cluster-replicas value
    # Formula: slave count / master count
    MASTER_COUNT=$(echo "${RedisMasterAddr}" | wc -w)
    SLAVE_COUNT=$(echo "${RedisSlaveAddr}" | wc -w)
    
    if [ "$MASTER_COUNT" -eq 0 ]; then
        echo "Error: No master nodes found."
        return 1
    fi
    
    REPLICAS=$((SLAVE_COUNT / MASTER_COUNT))
    
    echo "Master count: $MASTER_COUNT"
    echo "Slave count: $SLAVE_COUNT"
    echo "Replicas per master: $REPLICAS"
    
    # Cluster creation command
    CREATE_CMD="echo yes | $REDIS_HOME/bin/redis-cli --cluster create $ALL_NODES --cluster-replicas $REPLICAS"
    echo "Executing: $CREATE_CMD"
    
    eval "$CREATE_CMD"
    
    if [ $? -eq 0 ]; then
        echo "Redis Cluster created successfully!"
        return 0
    else
        echo "Error: Failed to create Redis Cluster."
        return 1
    fi
}

# Main function
main() {
    echo "=== Redis Cluster Auto-Setup Script ==="
    echo "Install Path: $REDIS_HOME"
    echo ""
    
    # Check node status
    if ! check_all_nodes; then
        echo "Not all Redis nodes are running. Cluster creation aborted."
        return 1
    fi
    
    echo ""
    echo "All nodes are running. Proceeding with cluster creation..."
    echo ""
    
    # Create cluster
    if create_cluster; then
        echo ""
        echo "=== Redis Cluster Setup Complete ==="
        echo "You can check cluster status with: $REDIS_HOME/bin/redis-cli -c -p ${redisMasterPort} cluster nodes"
        return 0
    else
        echo ""
        echo "=== Redis Cluster Setup Failed ==="
        return 1
    fi
}

# Execute main function
main
```

**redis-control.ftl：**

```shell
#!/bin/bash

# Redis installation path (script is in bin/ folder, so redis/ is in parent directory)
REDIS_HOME="${redisInstallPath}/redis"

# Define start and stop commands (binaries are in parent directory)
START_MASTER="$REDIS_HOME/bin/redis-server $REDIS_HOME/cluster/conf/redis-master.conf"
START_SLAVE="$REDIS_HOME/bin/redis-server $REDIS_HOME/cluster/conf/redis-slave.conf"
STOP_MASTER="$REDIS_HOME/bin/redis-cli -p ${redisMasterPort} shutdown"
STOP_SLAVE="$REDIS_HOME/bin/redis-cli -p ${redisSlavePort} shutdown"
STATUS_MASTER="$REDIS_HOME/bin/redis-cli -p ${redisMasterPort} ping"
STATUS_SLAVE="$REDIS_HOME/bin/redis-cli -p ${redisSlavePort} ping"

# Check if Master is configured
check_master_config() {
    if [ ! -f "$REDIS_HOME/cluster/conf/redis-master.conf" ]; then
        return 1
    fi
    return 0
}

# Check if Slave is configured
check_slave_config() {
    if [ ! -f "$REDIS_HOME/cluster/conf/redis-slave.conf" ]; then
        return 1
    fi
    return 0
}

# Start Master
start_master() {
    echo "Starting Redis Master..."
    $START_MASTER

    sleep 2

    status=$($STATUS_MASTER)
    if [ "$status" == "PONG" ]; then
        echo "Redis Master started successfully."
        return 0
    else
        echo "ERROR: Redis Master failed to start."
        return 1
    fi
}

# Start Slave
start_slave() {
    echo "Starting Redis Slave..."
    $START_SLAVE

    sleep 2

    status=$($STATUS_SLAVE)
    if [ "$status" == "PONG" ]; then
        echo "Redis Slave started successfully."
        return 0
    else
        echo "ERROR: Redis Slave failed to start."
        return 1
    fi
}

# Stop Master
stop_master() {
    echo "Stopping Redis Master..."
    $STOP_MASTER

    sleep 2

    redis_status=$($STATUS_MASTER)
    if [ "$redis_status" == "PONG" ]; then
        echo "WARNING: Redis Master is still running."
        return 1
    else
        echo "Redis Master stopped."
        return 0
    fi
}

# Stop Slave
stop_slave() {
    echo "Stopping Redis Slave..."
    $STOP_SLAVE

    sleep 2

    redis_status=$($STATUS_SLAVE)
    if [ "$redis_status" == "PONG" ]; then
        echo "WARNING: Redis Slave is still running."
        return 1
    else
        echo "Redis Slave stopped."
        return 0
    fi
}

# Execute operation
case $1 in
    start)
        case $2 in
            master)
                if ! check_master_config; then
                    echo "ERROR: Master is not configured."
                    exit 1
                fi
                start_master
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                ;;
            slave)
                if ! check_slave_config; then
                    echo "ERROR: Slave is not configured."
                    exit 1
                fi
                start_slave
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 start [master|slave]"
                exit 1
                ;;
        esac
        ;;
    stop)
        case $2 in
            master)
                if ! check_master_config; then
                    echo "ERROR: Master is not configured."
                    exit 1
                fi
                stop_master
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                ;;
            slave)
                if ! check_slave_config; then
                    echo "ERROR: Slave is not configured."
                    exit 1
                fi
                stop_slave
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 stop [master|slave]"
                exit 1
                ;;
        esac
        ;;
    status)
        case $2 in
            master)
                if ! check_master_config; then
                    echo "ERROR: Master is not configured."
                    exit 1
                fi
                redis_status=$($STATUS_MASTER)
                if [ "$redis_status" == "PONG" ]; then
                    echo "Redis Master is running."
                    exit 0
                else
                    echo "Redis Master is not running."
                    exit 1
                fi
                ;;
            slave)
                if ! check_slave_config; then
                    echo "ERROR: Slave is not configured."
                    exit 1
                fi
                redis_status=$($STATUS_SLAVE)
                if [ "$redis_status" == "PONG" ]; then
                    echo "Redis Slave is running."
                    exit 0
                else
                    echo "Redis Slave is not running."
                    exit 1
                fi
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 status [master|slave]"
                exit 1
                ;;
        esac
        ;;
    restart)
        case $2 in
            master)
                if ! check_master_config; then
                    echo "ERROR: Master is not configured."
                    exit 1
                fi
                echo "Restarting Redis Master..."
                stop_master
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                start_master
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                echo "Redis Master restarted successfully."
                ;;
            slave)
                if ! check_slave_config; then
                    echo "ERROR: Slave is not configured."
                    exit 1
                fi
                echo "Restarting Redis Slave..."
                stop_slave
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                start_slave
                if [ $? -ne 0 ]; then
                    exit 1
                fi
                echo "Redis Slave restarted successfully."
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 restart [master|slave]"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Invalid first parameter. Usage: $0 {start|stop|restart|status} [master|slave]"
        exit 1
        ;;
esac
```

**redis-master.ftl：**

```shell
bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisMasterPort}
logfile ${redisInstallPath}/redis/cluster/log/redis-master.log
pidfile ${redisInstallPath}/redis/cluster/pid/redis-master.pid
dir ${redisInstallPath}/redis/cluster
dbfilename dump-master.rdb
appendonly yes
appendfilename appendonly-master.aof

cluster-enabled yes
cluster-config-file ${redisInstallPath}/redis/cluster/conf/nodes-${redisMasterPort}.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
```

**redis-slave.ftl：**

```shell
bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisSlavePort}
logfile ${redisInstallPath}/redis/cluster/log/redis-slave.log
pidfile ${redisInstallPath}/redis/cluster/pid/redis-slave.pid
dir ${redisInstallPath}/redis/cluster
dbfilename dump-slave.rdb
appendonly yes
appendfilename appendonly-slave.aof

cluster-enabled yes
cluster-config-file ${redisInstallPath}/redis/cluster/conf/nodes-${redisSlavePort}.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
```

**redis-exporter-control.ftl**

```shell
#!/bin/bash

REDIS_HOME="${redisInstallPath}/redis"
REDIS_EXPORTER="$REDIS_HOME/bin/redis_exporter"

# Log functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
}

# Get PID file path (based on role)
get_pid_file() {
    local role=$1
    echo "$REDIS_HOME/cluster/pid/redis-exporter-$role.pid"
}

# Get log file path (based on role)
get_log_file() {
    local role=$1
    echo "$REDIS_HOME/cluster/log/redis-exporter-$role.log"
}

# Start single Exporter instance
start_single_exporter() {
    local role=$1
    local redis_port
    local exporter_port
    
    # Determine port based on role
    if [ "$role" == "master" ]; then
        redis_port="${redisMasterPort}"
        exporter_port="${redisExporterPortMaster}"
    elif [ "$role" == "slave" ]; then
        redis_port="${redisSlavePort}"
        exporter_port="${redisExporterPortWorker}"
    else
        log_error "Invalid role: $role. Must be 'master' or 'slave'"
        return 1
    fi
    
    # Use role-specific PID file and log file
    local pid_file=$(get_pid_file "$role")
    local log_file=$(get_log_file "$role")
    
    log_info "Starting Redis Exporter for role: $role"
    log_info "  Redis target: localhost:$redis_port"
    log_info "  Exporter port: $exporter_port"
    log_info "  PID file: $pid_file"
    log_info "  Log file: $log_file"
    
    # Check exporter executable file
    if [ ! -f "$REDIS_EXPORTER" ]; then
        log_error "Redis Exporter binary file does not exist: $REDIS_EXPORTER"
        return 1
    fi
    
    if [ ! -x "$REDIS_EXPORTER" ]; then
        log_error "Redis Exporter binary file does not have execute permission: $REDIS_EXPORTER"
        return 1
    fi
    
    # Check if already running
    if [ -f "$pid_file" ]; then
        old_pid=$(cat "$pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log_warn "Redis Exporter for role $role is already running (PID: $old_pid)"
            return 0
        else
            log_warn "Found stale PID file for role $role, cleaning up..."
            rm -f "$pid_file"
        fi
    fi
    
    # Start exporter
    export REDIS_ADDR="redis://localhost:$redis_port"
    export REDIS_EXPORTER_WEB_LISTEN_ADDRESS="0.0.0.0:$exporter_port"
    export REDIS_EXPORTER_NAMESPACE="redis"
    
    nohup $REDIS_EXPORTER \
        --redis.addr=$REDIS_ADDR \
        --web.listen-address=$REDIS_EXPORTER_WEB_LISTEN_ADDRESS \
        --namespace=redis \
        --is-cluster \
        > "$log_file" 2>&1 &
    
    local new_pid=$!
    
    # Wait for startup
    sleep 2
    
    # Check if started successfully
    if ps -p "$new_pid" > /dev/null 2>&1; then
        echo "$new_pid" > "$pid_file"
        log_info "Redis Exporter started successfully (PID: $new_pid)"
        
        # Verify port listening
        sleep 1
        if ss -tlnp 2>/dev/null | grep -q ":$exporter_port "; then
            log_info "Exporter is listening on port $exporter_port"
            return 0
        else
            log_warn "Exporter started but port $exporter_port not yet listening (may need more time)"
            return 0
        fi
    else
        log_error "Redis Exporter failed to start"
        rm -f "$pid_file"
        return 1
    fi
}

# Stop single Exporter instance
stop_single_exporter() {
    local role=$1
    local pid_file=$(get_pid_file "$role")
    
    if [ ! -f "$pid_file" ]; then
        log_warn "Redis Exporter PID file does not exist for role: $role"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    # Check if process exists
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter is not running (stale PID file)"
        rm -f "$pid_file"
        return 0
    fi
    
    # Graceful stop
    log_info "Stopping Redis Exporter for role: $role (PID: $pid)..."
    kill "$pid"
    
    # Wait for process to end
    local count=0
    local max_wait=10
    
    while [ $count -lt $max_wait ]; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            log_info "Redis Exporter stopped successfully"
            rm -f "$pid_file"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # Force stop
    log_warn "Redis Exporter did not stop gracefully, forcing termination..."
    kill -9 "$pid"
    sleep 1
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter force stopped"
        rm -f "$pid_file"
        return 0
    else
        log_error "Unable to stop Redis Exporter"
        return 1
    fi
}

# Restart single Exporter instance
restart_single_exporter() {
    local role=$1
    
    log_info "Restarting Redis Exporter for role: $role..."
    
    # Stop first
    if ! stop_single_exporter "$role"; then
        log_warn "Stop of Exporter for role $role failed, continuing with start..."
    fi
    
    # Wait (consistent with wait time after start_single_exporter)
    sleep 2
    
    # Then start
    if ! start_single_exporter "$role"; then
        log_error "Start of Exporter for role $role failed"
        return 1
    fi
    
    log_info "Redis Exporter for role: $role restarted successfully"
    return 0
}

# Check single Exporter instance status
check_single_exporter() {
    local role=$1
    local pid_file=$(get_pid_file "$role")
    local log_file=$(get_log_file "$role")
    
    if [ ! -f "$pid_file" ]; then
        log_info "Redis Exporter is not running (no PID file)"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter is running (PID: $pid)"
        log_info "  Log file: $log_file"
        
        # Display process info
        ps -p "$pid" -o pid,ppid,cmd --no-headers 2>/dev/null | sed 's/^/  /'
        
        return 0
    else
        log_info "Redis Exporter is not running (stale PID file)"
        rm -f "$pid_file"
        return 1
    fi
}

# Start Exporter (single role only)
start_exporter() {
    local role=$1
    if [ -z "$role" ]; then
        log_error "Missing role. Usage: $0 start [master|slave]"
        return 1
    fi
    
    if ! start_single_exporter "$role"; then
        log_error "Unable to start Exporter for role $role"
        return 1
    fi
    
    # Verify start result
    echo ""
    status_exporter "$role"
    return $?
}

# Stop Exporter (single role only)
stop_exporter() {
    local role=$1
    if [ -z "$role" ]; then
        log_error "Missing role. Usage: $0 stop [master|slave]"
        return 1
    fi
    
    if ! stop_single_exporter "$role"; then
        log_error "Unable to stop Exporter for role $role"
        return 1
    fi
    return 0
}

# Restart Exporter (single role only)
restart_exporter() {
    local role=$1
    if [ -z "$role" ]; then
        log_error "Missing role. Usage: $0 restart [master|slave]"
        return 1
    fi
    
    restart_single_exporter "$role"
    local result=$?
    
    # Verify restart result
    echo ""
    status_exporter "$role"
    return $result
}

# Check Exporter status (single role only)
status_exporter() {
    local role=$1
    if [ -z "$role" ]; then
        log_error "Missing role. Usage: $0 status [master|slave]"
        return 1
    fi
    
    check_single_exporter "$role"
    return $?
}

# Main function
main() {
    local command=$1
    local role=$2
    
    case "$command" in
        start)
            start_exporter "$role"
            ;;
        stop)
            stop_exporter "$role"
            ;;
        restart)
            restart_exporter "$role"
            ;;
        status)
            status_exporter "$role"
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status} {master|slave}"
            echo ""
            echo "Commands:"
            echo "  start    Start Redis Exporter for role"
            echo "  stop     Stop Redis Exporter for role"
            echo "  restart  Restart Redis Exporter for role"
            echo "  status   Check Redis Exporter status for role"
            echo ""
            echo "Roles:"
            echo "  master   Redis Master Exporter (port: \$redisExporterPortMaster)"
            echo "  slave    Redis Slave Exporter (port: \$redisExporterPortWorker)"
            echo ""
            echo "Examples:"
            echo "  $0 start master     # Start Master Exporter"
            echo "  $0 stop slave       # Stop Slave Exporter"
            echo "  $0 restart master   # Restart Master Exporter"
            echo "  $0 status master    # Check Master Exporter status"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"

```



## 3. 修改源码

**com.datasophon.api.strategy.RedisHandlerStrategy**

```java
package com.datasophon.worker.strategy;

import com.datasophon.common.Constants;
import com.datasophon.common.command.ServiceRoleOperateCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.ShellUtils;
import com.datasophon.worker.handler.ServiceHandler;

import java.sql.SQLException;
import java.util.Objects;

import org.apache.commons.lang3.StringUtils;

public class RedisHandlerStrategy extends AbstractHandlerStrategy implements ServiceRoleStrategy {
    
    public RedisHandlerStrategy(String serviceName, String serviceRoleName) {
        super(serviceName, serviceRoleName);
    }
    
    @Override
    public ExecResult handler(ServiceRoleOperateCommand command) throws SQLException, ClassNotFoundException {
        ServiceHandler serviceHandler = new ServiceHandler(command.getServiceName(), command.getServiceRoleName());
        String workPath = Constants.INSTALL_PATH + Constants.SLASH + command.getDecompressPackageName();
        ExecResult result;
        
        CommandType commandType = command.getCommandType();
        String exporterRole = resolveExporterRole(command.getServiceRoleName());
        
        switch (commandType) {
            case INSTALL_SERVICE:

                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult clusterResult = ShellUtils.exceShell("bash " + workPath + "/redis-cluster.sh");
                if (!clusterResult.getExecResult()) {
                    return withFailureContext("redis-cluster.sh", clusterResult);
                }
                ExecResult exporterResult = startRedisExporter(workPath, exporterRole);
                if (!exporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", exporterResult);
                }
                break;
            
            case START_SERVICE:
            case START_WITH_CONFIG:

                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult startExporterResult = startRedisExporter(workPath, exporterRole);
                if (!startExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", startExporterResult);
                }
                break;

            case STOP_SERVICE:

                result = serviceHandler.stop(command.getStopRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult stopExporterResult = stopRedisExporter(workPath, exporterRole);
                if (!stopExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", stopExporterResult);
                }
                break;

            case RESTART_SERVICE:
            case RESTART_WITH_CONFIG:

                result = serviceHandler.reStart(command.getRestartRunner(), command.getDecompressPackageName());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult restartExporterResult = restartRedisExporter(workPath, exporterRole);
                if (!restartExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", restartExporterResult);
                }
                break;

            default:
                result = new ExecResult();
                result.setExecResult(false);
                result.setExecOut("Unsupported command type: " + commandType);
        }
        
        return result;
    }
    
    private ExecResult startRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "start", exporterRole);
    }
    
    private ExecResult stopRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "stop", exporterRole);
    }
    
    private ExecResult restartRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "restart", exporterRole);
    }
    
    private ExecResult execRedisExporter(String workPath, String action, String exporterRole) {
        if (!StringUtils.isNotBlank(exporterRole)) {
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut("redis-exporter role is empty, action: " + action);
            return result;
        }
        try {
            String command = "bash " + workPath + "/bin/redis-exporter-control.sh " + action + " " + exporterRole;
            ExecResult result = ShellUtils.exceShell(command);
            if (!result.getExecResult()) {
                logger.warn("Failed to {} redis_exporter({}): {}", action, exporterRole, result.getExecOut());
            }
            return result;
        } catch (Exception e) {
            logger.warn("Failed to {} redis_exporter({}): {}", action, exporterRole, e.getMessage());
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut(e.getMessage());
            return result;
        }
    }
    
    private String resolveExporterRole(String serviceRoleName) {
        if (!StringUtils.isNotBlank(serviceRoleName)) {
            return null;
        }
        if ("RedisMaster".equals(serviceRoleName)) {
            return "master";
        }
        if ("RedisWorker".equals(serviceRoleName)) {
            return "slave";
        }
        return null;
    }

    private ExecResult withFailureContext(String stepName, ExecResult result) {
        ExecResult finalResult = Objects.nonNull(result) ? result : new ExecResult();
        finalResult.setExecResult(false);
        String execOut = finalResult.getExecOut();
        if (Objects.nonNull(execOut) && !execOut.isEmpty()) {
            finalResult.setExecOut(stepName + " failed: " + execOut);
        } else {
            finalResult.setExecOut(stepName + " failed");
        }
        return finalResult;
    }
}

```

**com.datasophon.api.strategy.ServiceRoleStrategyContext**

```java
map.put("REDIS", new RedisHandlerStrategy());
serviceNameMap.put("RedisMaster", "REDIS");
serviceNameMap.put("RedisWorker", "REDIS");
```

**com.datasophon.worker.strategy.RedisHandlerStrategy**

```java
package com.datasophon.worker.strategy;

import com.datasophon.common.Constants;
import com.datasophon.common.command.ServiceRoleOperateCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.ShellUtils;
import com.datasophon.worker.handler.ServiceHandler;

import java.sql.SQLException;

public class RedisHandlerStrategy extends AbstractHandlerStrategy implements ServiceRoleStrategy {

    public RedisHandlerStrategy(String serviceName, String serviceRoleName) {
        super(serviceName, serviceRoleName);
    }

    @Override
    public ExecResult handler(ServiceRoleOperateCommand command) throws SQLException, ClassNotFoundException {
        ServiceHandler serviceHandler = new ServiceHandler(command.getServiceName(), command.getServiceRoleName());
        String workPath = Constants.INSTALL_PATH + Constants.SLASH + command.getDecompressPackageName();
        ExecResult startResult;

        if (command.getCommandType().equals(CommandType.INSTALL_SERVICE)) {
            startResult = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                    command.getDecompressPackageName(), command.getRunAs());
            ShellUtils.exceShell("bash " + workPath + "/redis-cluster.sh");
        }

        startResult = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                command.getDecompressPackageName(), command.getRunAs());
        return startResult;
    }
}
```

**com.datasophon.worker.strategy.ServiceRoleStrategyContext**

```java
map.put("RedisMaster", new RedisHandlerStrategy("REDIS", "RedisMaster"));
map.put("RedisWorker", new RedisHandlerStrategy("REDIS", "RedisWorker"));
```

## 4. Prometheus监控

prometheus.ftl

```shell
  - job_name: 'redis_exporter'
    metrics_path: '/metrics'
    file_sd_configs:
      - files:
        - configs/redismaster.json
        - configs/redisworker.json
```

## 5. grafana监控面板

1. 进入ddp01:3000网址 进入grafana 

2. 登录默认用户名：admin 密码：admin 

3. 点击dashboards 点击imports

4. 导入下载的 [redis模板](https://grafana.com/grafana/dashboards/763-redis-dashboard-for-prometheus-redis-exporter-1-x/?spm=5176.28103460.0.0.16147551jntpEb)

5. datasophon mysql表 `t_ddh_cluster_service_dashboard` 新增图标链接，id列是自增的，不需要插入数据。

   ```sql
   -- src/main/resources/db/migration/1.2.1/V1.2.1__DML.sql
   INSERT INTO `t_ddh_cluster_service_dashboard` (service_name, dashboard_url) VALUES ('REDIS','http://${grafanaHost}:3000/d/11bbfabb-8f8e-4f58-937d-4f5af170484e/redis?orgId=1&kiosk=tv')
   ```

   

## 6. 重新打包

`mvn spotless:apply `
`mvn clean package -DskipTests`

将新的`datasophon-worker.tar.gz datasophon-manager-1.2.1.tar.gz` 放到`/opt/datasophon`下解压

## 7. 重启

各节点worker重启

```shell
bash /opt/datasophon/datasophon-worker/bin/datasophon-worker.sh stop worker
bash /opt/datasophon/datasophon-worker/bin/datasophon-worker.sh start worker
```

主节点重启api

```shell
bash /opt/apps/datasophon-manager-1.2.1/bin/datasophon-api.sh stop api
bash /opt/apps/datasophon-manager-1.2.1/bin/datasophon-api.sh start api
```

## 8. 安装Redis

## 9. 注意事项

1. redis建议在glibc的版本上编译，否则会提高需要的glibc版本
2. redis在arm机器上编译是arm版本，在x86机器上编译是x86版本
3. redis的master和worker数量必须满足`master!=0&&worker>=master&&work%master==0` ，在代码中添加相关限制可以参考[datasophon](https://github.com/DKShowMaker/datasophon)
4. 

