#!/bin/bash

# 定义启动和停止命令
START_MASTER="/opt/datasophon/redis/redis-server /opt/datasophon/redis/cluster/conf/redis-master.conf"
START_SLAVE="/opt/datasophon/redis/redis-server /opt/datasophon/redis/cluster/conf/redis-slave.conf"
STOP_MASTER="/opt/datasophon/redis/redis-cli -p ${redisMasterPort} shutdown"
STOP_SLAVE="/opt/datasophon/redis/redis-cli -p ${redisSlavePort} shutdown"
STATUS_MASTER="/opt/datasophon/redis/redis-cli -p ${redisMasterPort} ping"
STATUS_SLAVE="/opt/datasophon/redis/redis-cli -p ${redisSlavePort} ping"

# 启动Master
start_master() {
    echo "Starting Redis Master..."
    $START_MASTER
}

# 启动Slave
start_slave() {
    echo "Starting Redis Slave..."
    $START_SLAVE
}

# 停止Master
stop_master() {
    echo "Stopping Redis Master..."
    $STOP_MASTER
}

# 停止Slave
stop_slave() {
    echo "Stopping Redis Slave..."
    $STOP_SLAVE
}

# 检查状态并根据返回值决定退出码
check_status() {
    echo "Checking Redis status..."
    status=$($1)  # 使用传递的命令获取状态
    if [ "$status" == "PONG" ]; then
        echo "Redis is running."
        exit 0
    else
        echo "Redis is not running."
        exit 1
    fi
}

# 执行操作
case $1 in
    start)
        case $2 in
            master)
                start_master
                ;;
            slave)
                start_slave
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 start {master|slave}"
                exit 1
                ;;
        esac
        ;;
    stop)
        case $2 in
            master)
                stop_master
                ;;
            slave)
                stop_slave
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 stop {master|slave}"
                exit 1
                ;;
        esac
        ;;
    status)
        case $2 in
            master)
                check_status "$STATUS_MASTER"
                ;;
            slave)
                check_status "$STATUS_SLAVE"
                ;;
            *)
                echo "Invalid second parameter. Usage: $0 status {master|slave}"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Invalid first parameter. Usage: $0 {start|stop|status} {master|slave}"
        exit 1
        ;;
esac
