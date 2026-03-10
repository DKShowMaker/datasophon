#!/bin/bash

# Redis installation path (script is in bin/ folder, so redis/ is in parent directory)
REDIS_HOME="${redisInstallPath}/redis"

# Exporter control script (generated into the same bin/ directory)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORTER_CTL="$SCRIPT_DIR/redis-exporter-control.sh"

run_exporter() {
    local action=$1
    local role=$2
    if [ ! -f "$EXPORTER_CTL" ]; then
        echo "ERROR: redis-exporter-control.sh not found: $EXPORTER_CTL"
        return 1
    fi
    bash "$EXPORTER_CTL" "$action" "$role"
    return $?
}

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
        if ! run_exporter start master; then
            echo "ERROR: Redis Master exporter failed to start."
            return 1
        fi
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
        if ! run_exporter start slave; then
            echo "ERROR: Redis Slave exporter failed to start."
            return 1
        fi
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
        if ! run_exporter stop master; then
            echo "ERROR: Redis Master exporter failed to stop."
            return 1
        fi
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
        if ! run_exporter stop slave; then
            echo "ERROR: Redis Slave exporter failed to stop."
            return 1
        fi
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
