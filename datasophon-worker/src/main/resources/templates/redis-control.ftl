#!/bin/bash

# Redis 安装路径（脚本在 bin/ 目录下，所以 redis/ 在上一级目录）
REDIS_HOME="${redisInstallPath}/redis"

# 定义启动和停止命令（二进制在上一级目录）
START_MASTER="$REDIS_HOME/bin/redis-server $REDIS_HOME/cluster/conf/redis-master.conf"
START_SLAVE="$REDIS_HOME/bin/redis-server $REDIS_HOME/cluster/conf/redis-slave.conf"
STOP_MASTER="$REDIS_HOME/bin/redis-cli -p ${redisMasterPort} shutdown"
STOP_SLAVE="$REDIS_HOME/bin/redis-cli -p ${redisSlavePort} shutdown"
STATUS_MASTER="$REDIS_HOME/bin/redis-cli -p ${redisMasterPort} ping"
STATUS_SLAVE="$REDIS_HOME/bin/redis-cli -p ${redisSlavePort} ping"

# 启动Master
start_master() {
    echo "Starting Redis Master..."
    $START_MASTER
    
    # 等待 Redis 启动
    sleep 2
    
    # 检查 Redis 是否启动成功
    status=$($STATUS_MASTER)
    if [ "$status" == "PONG" ]; then
        echo "Redis Master started successfully."
        return 0
    else
        echo "ERROR: Redis Master failed to start."
        return 1
    fi
}

# 启动Slave
start_slave() {
    echo "Starting Redis Slave..."
    $START_SLAVE
    
    # 等待 Redis 启动
    sleep 2
    
    # 检查 Redis 是否启动成功
    status=$($STATUS_SLAVE)
    if [ "$status" == "PONG" ]; then
        echo "Redis Slave started successfully."
        return 0
    else
        echo "ERROR: Redis Slave failed to start."
        return 1
    fi
}

# 停止Master
stop_master() {
    echo "Stopping Redis Master..."
    $STOP_MASTER
    
    # 等待 Redis 完全停止
    sleep 2
    
    echo "Redis Master stopped."
}

# 停止Slave
stop_slave() {
    echo "Stopping Redis Slave..."
    $STOP_SLAVE
    
    # 等待 Redis 完全停止
    sleep 2
    
    echo "Redis Slave stopped."
}

# 检查状态
check_status() {
    echo "Checking Redis status..."
    redis_status=$($1)
    
    if [ "$redis_status" == "PONG" ]; then
        echo "Redis is running."
    else
        echo "Redis is not running."
    fi
    
    return 0
}

# 重启Master
restart_master() {
    echo "Restarting Redis Master..."
    stop_master
    sleep 2
    start_master
}

# 重启Slave
restart_slave() {
    echo "Restarting Redis Slave..."
    stop_slave
    sleep 2
    start_slave
}

# 重启Redis（支持单个或批量）
restart_redis() {
    local role=$1
    
    case $role in
        "")
            echo "Restarting all Redis instances..."
            restart_redis slave
            restart_redis master
            echo "All Redis instances restarted."
            ;;
        master)
            restart_master
            ;;
        slave)
            restart_slave
            ;;
    esac
}

# 执行操作
case $1 in
    start)
        case $2 in
            "")
                echo "Starting all Redis instances..."
                start_master
                start_slave
                echo "All Redis instances started."
                ;;
            master)
                start_master
                ;;
            slave)
                start_slave
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 start [master|slave]"
                exit 1
                ;;
        esac
        ;;
    stop)
        case $2 in
            "")
                echo "Stopping all Redis instances..."
                stop_slave
                stop_master
                echo "All Redis instances stopped."
                ;;
            master)
                stop_master
                ;;
            slave)
                stop_slave
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 stop [master|slave]"
                exit 1
                ;;
        esac
        ;;
    status)
        case $2 in
            "")
                echo "Checking status of all Redis instances..."
                echo ""
                echo "=== Redis Master Status ==="
                check_status "$STATUS_MASTER"
                echo ""
                echo "=== Redis Slave Status ==="
                check_status "$STATUS_SLAVE"
                ;;
            master)
                check_status "$STATUS_MASTER"
                ;;
            slave)
                check_status "$STATUS_SLAVE"
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 status [master|slave]"
                exit 1
                ;;
        esac
        ;;
    restart)
        case $2 in
            "")
                restart_redis ""
                ;;
            master|slave)
                restart_redis "$2"
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
