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
