#!/bin/bash

#============================================================================
# Redis Exporter Control Script
#
# Function: Manage Prometheus Exporter for Redis Cluster mode
#
# Deployment constraints:
#   - Only supports Redis Cluster mode
#   - One physical machine runs at most 1 master and 1 slave
#   - Maximum 2 Exporter instances
#   - Each Exporter instance has independent PID file and log file
#
# File structure:
#   bin/redis-exporter-control.sh    # This script
#   bin/redis-exporter              # Exporter binary
#   cluster/pid/
#     ├── redis-exporter-master.pid  # Master Exporter PID
#     └── redis-exporter-slave.pid   # Slave Exporter PID
#   cluster/log/
#     ├── redis_exporter_master.log  # Master Exporter log
#     └── redis_exporter_slave.log   # Slave Exporter log
#
# Usage:
#   start                        # Start all Exporter instances
#   start master/slave           # Start Exporter for specified role
#   stop                         # Stop all Exporter instances (slave first, then master)
#   stop master/slave            # Stop Exporter for specified role
#   status                       # Check status of all Exporters
#   status master/slave          # Check status of Exporter for specified role
#
# Notes:
#   - Single instance mode is not supported
#   - Default redis_exporter.pid is not used
#   - All logs are recorded to role-specific log files
#   - For batch operations, instance failures are logged but do not affect subsequent operations
#   - Auto-call status after startup to verify
#   - Stop order: slave first, then master (to avoid data loss)
#   - Stop strategy: send TERM signal first, then KILL signal after timeout
#
# Author: Datasophon Team
# Version: 1.0
#============================================================================

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

# Start Exporter (supports single or batch)
start_exporter() {
    local role=$1
    
    # If role is not specified, start all instances
    if [ -z "$role" ]; then
        log_info "Starting all Redis Exporter instances..."
        local all_started=true
        
        # Sequential start: master first, then slave
        for r in master slave; do
            log_info ""
            if ! start_single_exporter "$r"; then
                log_error "Unable to start Exporter for role $r"
                all_started=false
            fi
        done
        
        echo ""
        if [ "$all_started" = true ]; then
            log_info "All Exporters started successfully"
            # Auto-verify start result
            echo ""
            status_exporter
            return $?
        else
            log_error "Some Exporters failed to start"
            return 1
        fi
    else
        # Start specified instance
        if ! start_single_exporter "$role"; then
            log_error "Unable to start Exporter for role $role"
            return 1
        fi
        
        # Verify start result
        echo ""
        status_exporter "$role"
        return $?
    fi
}

# Stop Exporter (supports single or batch)
stop_exporter() {
    local role=$1
    
    # If role is not specified, stop all instances
    if [ -z "$role" ]; then
        log_info "Stopping all Redis Exporter instances..."
        local all_stopped=true
        
        # Sequential stop: slave first, then master (recommended order)
        for r in slave master; do
            log_info ""
            if ! stop_single_exporter "$r"; then
                log_error "Unable to stop Exporter for role $r"
                all_stopped=false
            fi
        done
        
        echo ""
        if [ "$all_stopped" = true ]; then
            log_info "All Exporters stopped"
            return 0
        else
            log_error "Some Exporters failed to stop"
            return 1
        fi
    else
        # Stop specified instance
        if ! stop_single_exporter "$role"; then
            log_error "Unable to stop Exporter for role $role"
            return 1
        fi
    fi
}

# Restart Exporter (supports single or batch)
restart_exporter() {
    local role=$1
    
    # If role is not specified, restart all instances
    if [ -z "$role" ]; then
        log_info "Restarting all Redis Exporter instances..."
        
        # Step 1: Stop all instances (slave first, then master)
        echo ""
        log_info "Step 1/2: Stopping all Exporter instances..."
        local all_stopped=true
        for r in slave master; do
            log_info ""
            if ! stop_single_exporter "$r"; then
                log_error "Unable to stop Exporter for role $r"
                all_stopped=false
            fi
        done
        
        # Wait (consistent with wait time after start_single_exporter)
        sleep 2
        
        # Step 2: Start all instances (master first, then slave)
        echo ""
        log_info "Step 2/2: Starting all Exporter instances..."
        local all_started=true
        for r in master slave; do
            log_info ""
            if ! start_single_exporter "$r"; then
                log_error "Unable to start Exporter for role $r"
                all_started=false
            fi
        done
        
        # Summary
        echo ""
        if [ "$all_stopped" = true ] && [ "$all_started" = true ]; then
            log_info "All Exporters restarted successfully"
            # Auto-verify restart result
            echo ""
            status_exporter
            return 0
        else
            log_error "Some Exporters failed to restart"
            return 1
        fi
    else
        # Restart specified instance
        restart_single_exporter "$role"
        local result=$?
        
        # Verify restart result
        echo ""
        status_exporter "$role"
        return $result
    fi
}

# Check Exporter status (supports single or batch)
status_exporter() {
    local role=$1
    
    # If role is not specified, check all instances
    if [ -z "$role" ]; then
        log_info "Checking all Redis Exporter instances..."
        echo ""
        
        local total_running=0
        local total_instances=0
        
        for r in master slave; do
            echo "--- $r Exporter Status ---"
            if check_single_exporter "$r"; then
                total_running=$((total_running + 1))
            fi
            total_instances=$((total_instances + 1))
            echo ""
        done
        
        echo "===================================="
        if [ $total_running -eq $total_instances ]; then
            log_info "Summary: All $total_instances instances are running"
            return 0
        elif [ $total_running -eq 0 ]; then
            log_info "Summary: No instances are running"
            return 1
        else
            log_info "Summary: $total_running/$total_instances instances are running"
            return 0
        fi
    else
        # Check specified instance
        check_single_exporter "$role"
        return $?
    fi
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
            echo "Usage: $0 {start|stop|restart|status} [master|slave]"
            echo ""
            echo "Commands:"
            echo "  start    Start Redis Exporter (no parameter to start all instances)"
            echo "  stop     Stop Redis Exporter (no parameter to stop all instances)"
            echo "  restart  Restart Redis Exporter (no parameter to restart all instances)"
            echo "  status   Check Redis Exporter status (no parameter to check all instances)"
            echo ""
            echo "Roles (optional, defaults to all instances if not specified):"
            echo "  master   Redis Master Exporter (port: \$redisExporterPortMaster)"
            echo "  slave    Redis Slave Exporter (port: \$redisExporterPortWorker)"
            echo ""
            echo "Examples:"
            echo "  $0 start            # Start all Exporters"
            echo "  $0 start master     # Start Master Exporter"
            echo "  $0 stop             # Stop all Exporters"
            echo "  $0 stop slave       # Stop Slave Exporter"
            echo "  $0 restart          # Restart all Exporters"
            echo "  $0 restart master   # Restart Master Exporter"
            echo "  $0 status           # Check all Exporters status"
            echo "  $0 status master    # Check Master Exporter status"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
