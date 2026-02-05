#!/bin/bash

#============================================================================
# Redis Exporter 控制脚本
#
# 功能：管理 Redis Cluster 模式的 Prometheus Exporter
#
# 部署约束：
#   - 仅支持 Redis Cluster 模式
#   - 一个物理机最多运行 1 个 master 和 1 个 slave
#   - 最多存在 2 个 Exporter 实例
#   - 每个 Exporter 实例有独立的 PID 文件和日志文件
#
# 文件结构：
#   bin/redis-exporter-control.sh    # 本脚本
#   bin/redis-exporter              # Exporter 二进制
#   cluster/pid/
#     ├── redis-exporter-master.pid  # Master Exporter PID
#     └── redis-exporter-slave.pid   # Slave Exporter PID
#   cluster/log/
#     ├── redis_exporter_master.log  # Master Exporter 日志
#     └── redis_exporter_slave.log   # Slave Exporter 日志
#
# 使用方法：
#   start                        # 启动所有 Exporter 实例
#   start master/slave           # 启动指定角色的 Exporter
#   stop                         # 停止所有 Exporter 实例（先停 slave，后停 master）
#   stop master/slave            # 停止指定角色的 Exporter
#   status                       # 查看所有 Exporter 状态
#   status master/slave          # 查看指定角色的 Exporter 状态
#
# 注意事项：
#   - 不支持单实例模式
#   - 不使用默认的 redis_exporter.pid
#   - 所有的日志都记录到角色特定的日志文件中
#   - 批量操作时，某个实例失败会记录错误但不影响后续操作
#   - 启动后自动调用 status 验证启动结果
#   - 停止顺序：先 slave 后 master（避免数据丢失）
#   - 停止策略：先发送 TERM 信号，超时后发送 KILL 信号
#
# 作者：Datasophon Team
# 版本：1.0
#============================================================================

REDIS_HOME="${redisInstallPath}/redis"
REDIS_EXPORTER="$REDIS_HOME/bin/redis_exporter"

# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
}

# 获取 PID 文件路径（根据角色）
get_pid_file() {
    local role=$1
    echo "$REDIS_HOME/cluster/pid/redis-exporter-$role.pid"
}

# 获取日志文件路径（根据角色）
get_log_file() {
    local role=$1
    echo "$REDIS_HOME/cluster/log/redis-exporter-$role.log"
}

# 启动单个 Exporter 实例
start_single_exporter() {
    local role=$1
    local redis_port
    local exporter_port
    
    # 根据角色确定端口
    if [ "$role" == "master" ]; then
        redis_port="${redisMasterPort}"
        exporter_port="${redisExporterPortMaster}"
    elif [ "$role" == "slave" ]; then
        redis_port="${redisSlavePort}"
        exporter_port="${redisExporterPortWorker}"
    else
        log_error "无效的角色: $role. 必须是 'master' 或 'slave'"
        return 1
    fi
    
    # 使用角色特定的 PID 文件和日志文件
    local pid_file=$(get_pid_file "$role")
    local log_file=$(get_log_file "$role")
    
    log_info "启动 Redis Exporter for role: $role"
    log_info "  Redis 目标: localhost:$redis_port"
    log_info "  Exporter 端口: $exporter_port"
    log_info "  PID 文件: $pid_file"
    log_info "  日志文件: $log_file"
    
    # 检查 exporter 可执行文件
    if [ ! -f "$REDIS_EXPORTER" ]; then
        log_error "Redis Exporter 二进制文件不存在: $REDIS_EXPORTER"
        return 1
    fi
    
    if [ ! -x "$REDIS_EXPORTER" ]; then
        log_error "Redis Exporter 二进制文件没有执行权限: $REDIS_EXPORTER"
        return 1
    fi
    
    # 检查是否已经运行
    if [ -f "$pid_file" ]; then
        old_pid=$(cat "$pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            log_warn "Redis Exporter for role $role 已经在运行 (PID: $old_pid)"
            return 0
        else
            log_warn "发现过时的 PID 文件 for role $role，正在清理..."
            rm -f "$pid_file"
        fi
    fi
    
    # 启动 exporter
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
    
    # 等待启动
    sleep 2
    
    # 检查是否启动成功
    if ps -p "$new_pid" > /dev/null 2>&1; then
        echo "$new_pid" > "$pid_file"
        log_info "Redis Exporter 启动成功 (PID: $new_pid)"
        
        # 验证端口监听
        sleep 1
        if ss -tlnp 2>/dev/null | grep -q ":$exporter_port "; then
            log_info "Exporter 正在监听端口 $exporter_port"
            return 0
        else
            log_warn "Exporter 已启动但端口 $exporter_port 尚未监听（可能需要更多时间）"
            return 0
        fi
    else
        log_error "Redis Exporter 启动失败"
        rm -f "$pid_file"
        return 1
    fi
}

# 停止单个 Exporter 实例
stop_single_exporter() {
    local role=$1
    local pid_file=$(get_pid_file "$role")
    
    if [ ! -f "$pid_file" ]; then
        log_warn "Redis Exporter PID 文件不存在 for role: $role"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    # 检查进程是否存在
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter 未在运行 (过时的 PID 文件)"
        rm -f "$pid_file"
        return 0
    fi
    
    # 优雅停止
    log_info "正在停止 Redis Exporter for role: $role (PID: $pid)..."
    kill "$pid"
    
    # 等待进程结束
    local count=0
    local max_wait=10
    
    while [ $count -lt $max_wait ]; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            log_info "Redis Exporter 停止成功"
            rm -f "$pid_file"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # 强制停止
    log_warn "Redis Exporter 未优雅停止，强制终止..."
    kill -9 "$pid"
    sleep 1
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter 已强制停止"
        rm -f "$pid_file"
        return 0
    else
        log_error "无法停止 Redis Exporter"
        return 1
    fi
}

# 重启单个 Exporter 实例
restart_single_exporter() {
    local role=$1
    
    log_info "重启 Redis Exporter for role: $role..."
    
    # 先停止
    if ! stop_single_exporter "$role"; then
        log_warn "停止 role $role 的 Exporter 失败，继续启动..."
    fi
    
    # 等待（与 start_single_exporter 启动后等待时间一致）
    sleep 2
    
    # 再启动
    if ! start_single_exporter "$role"; then
        log_error "启动 role $role 的 Exporter 失败"
        return 1
    fi
    
    log_info "Redis Exporter for role: $role 重启成功"
    return 0
}

# 检查单个 Exporter 实例状态
check_single_exporter() {
    local role=$1
    local pid_file=$(get_pid_file "$role")
    local log_file=$(get_log_file "$role")
    
    if [ ! -f "$pid_file" ]; then
        log_info "Redis Exporter 未在运行 (没有 PID 文件)"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if ps -p "$pid" > /dev/null 2>&1; then
        log_info "Redis Exporter 正在运行 (PID: $pid)"
        log_info "  日志文件: $log_file"
        
        # 显示进程信息
        ps -p "$pid" -o pid,ppid,cmd --no-headers 2>/dev/null | sed 's/^/  /'
        
        return 0
    else
        log_info "Redis Exporter 未在运行 (过时的 PID 文件)"
        rm -f "$pid_file"
        return 1
    fi
}

# 启动 Exporter（支持单个或批量）
start_exporter() {
    local role=$1
    
    # 如果未指定角色，启动所有实例
    if [ -z "$role" ]; then
        log_info "正在启动所有 Redis Exporter 实例..."
        local all_started=true
        
        # 顺序启动：先 master，后 slave
        for r in master slave; do
            log_info ""
            if ! start_single_exporter "$r"; then
                log_error "无法启动 role $r 的 Exporter"
                all_started=false
            fi
        done
        
        echo ""
        if [ "$all_started" = true ]; then
            log_info "所有 Exporter 启动成功"
            # 自动验证启动结果
            echo ""
            status_exporter
            return $?
        else
            log_error "部分 Exporter 启动失败"
            return 1
        fi
    else
        # 启动指定实例
        if ! start_single_exporter "$role"; then
            log_error "无法启动 role $role 的 Exporter"
            return 1
        fi
        
        # 验证启动结果
        echo ""
        status_exporter "$role"
        return $?
    fi
}

# 停止 Exporter（支持单个或批量）
stop_exporter() {
    local role=$1
    
    # 如果未指定角色，停止所有实例
    if [ -z "$role" ]; then
        log_info "正在停止所有 Redis Exporter 实例..."
        local all_stopped=true
        
        # 顺序停止：先 slave，后 master（推荐顺序）
        for r in slave master; do
            log_info ""
            if ! stop_single_exporter "$r"; then
                log_error "无法停止 role $r 的 Exporter"
                all_stopped=false
            fi
        done
        
        echo ""
        if [ "$all_stopped" = true ]; then
            log_info "所有 Exporter 已停止"
            return 0
        else
            log_error "部分 Exporter 停止失败"
            return 1
        fi
    else
        # 停止指定实例
        if ! stop_single_exporter "$role"; then
            log_error "无法停止 role $role 的 Exporter"
            return 1
        fi
    fi
}

# 重启 Exporter（支持单个或批量）
restart_exporter() {
    local role=$1
    
    # 如果未指定角色，重启所有实例
    if [ -z "$role" ]; then
        log_info "正在重启所有 Redis Exporter 实例..."
        
        # 步骤 1：停止所有实例（先 slave，后 master）
        echo ""
        log_info "步骤 1/2: 停止所有 Exporter 实例..."
        local all_stopped=true
        for r in slave master; do
            log_info ""
            if ! stop_single_exporter "$r"; then
                log_error "无法停止 role $r 的 Exporter"
                all_stopped=false
            fi
        done
        
        # 等待（与 start_single_exporter 启动后等待时间一致）
        sleep 2
        
        # 步骤 2：启动所有实例（先 master，后 slave）
        echo ""
        log_info "步骤 2/2: 启动所有 Exporter 实例..."
        local all_started=true
        for r in master slave; do
            log_info ""
            if ! start_single_exporter "$r"; then
                log_error "无法启动 role $r 的 Exporter"
                all_started=false
            fi
        done
        
        # 总结
        echo ""
        if [ "$all_stopped" = true ] && [ "$all_started" = true ]; then
            log_info "所有 Exporter 重启成功"
            # 自动验证重启结果
            echo ""
            status_exporter
            return 0
        else
            log_error "部分 Exporter 重启失败"
            return 1
        fi
    else
        # 重启指定实例
        restart_single_exporter "$role"
        local result=$?
        
        # 验证重启结果
        echo ""
        status_exporter "$role"
        return $result
    fi
}

# 检查 Exporter 状态（支持单个或批量）
status_exporter() {
    local role=$1
    
    # 如果未指定角色，检查所有实例
    if [ -z "$role" ]; then
        log_info "正在检查所有 Redis Exporter 实例..."
        echo ""
        
        local total_running=0
        local total_instances=0
        
        for r in master slave; do
            echo "--- $r Exporter 状态 ---"
            if check_single_exporter "$r"; then
                total_running=$((total_running + 1))
            fi
            total_instances=$((total_instances + 1))
            echo ""
        done
        
        echo "===================================="
        if [ $total_running -eq $total_instances ]; then
            log_info "总结: 所有 $total_instances 个实例正在运行"
            return 0
        elif [ $total_running -eq 0 ]; then
            log_info "总结: 没有实例在运行"
            return 1
        else
            log_info "总结: $total_running/$total_instances 个实例正在运行"
            return 0
        fi
    else
        # 检查指定实例
        check_single_exporter "$role"
        return $?
    fi
}

# 主函数
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
            echo "使用方法：$0 {start|stop|restart|status} [master|slave]"
            echo ""
            echo "命令："
            echo "  start    启动 Redis Exporter（不指定参数启动所有实例）"
            echo "  stop     停止 Redis Exporter（不指定参数停止所有实例）"
            echo "  restart  重启 Redis Exporter（不指定参数重启所有实例）"
            echo "  status   查看 Redis Exporter 状态（不指定参数查看所有实例）"
            echo ""
            echo "角色（可选，不指定默认作用于所有实例）："
            echo "  master   Redis Master 的 Exporter（端口：\$redisExporterPortMaster）"
            echo "  slave    Redis Worker 的 Exporter（端口：\$redisExporterPortWorker）"
            echo ""
            echo "示例："
            echo "  $0 start            # 启动所有 Exporter"
            echo "  $0 start master     # 启动 Master Exporter"
            echo "  $0 stop             # 停止所有 Exporter"
            echo "  $0 stop slave       # 停止 Slave Exporter"
            echo "  $0 restart          # 重启所有 Exporter"
            echo "  $0 restart master   # 重启 Master Exporter"
            echo "  $0 status           # 查看所有 Exporter 状态"
            echo "  $0 status master    # 查看 Master Exporter 状态"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
