#!/bin/bash

# Redis Cluster 自动创建脚本
# 使用 --cluster-replicas 1 自动分配 Slave 节点

# 所有节点地址（Master和Worker）
ALL_NODES="${RedisMasterAddr} ${RedisSlaveAddr}"

# Redis 安装路径
REDIS_HOME="${redisInstallPath}/redis"

# 检查所有节点是否都已启动
check_all_nodes() {
    echo "Checking if all Redis nodes are running..."
    
    for node in $ALL_NODES; do
        host=$(echo "$node" | cut -d ":" -f 1)
        port=$(echo "$node" | cut -d ":" -f 2)
        
        # 使用 redis-cli ping 检查节点状态
        if ! $REDIS_HOME/bin/redis-cli -h $host -p $port ping > /dev/null 2>&1; then
            echo "Redis node $node is not running."
            return 1
        fi
        echo "Redis node $node is running."
    done
    
    return 0
}

# 创建集群（自动分配 Slave）
create_cluster() {
    echo "Creating Redis Cluster with auto-assigned slaves..."
    echo "Nodes: $ALL_NODES"
    
    # 计算 --cluster-replicas 的值
    # 如果有 3 Master 和 3 Slave，则 replica=1
    # 公式: slave数量 / master数量
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
    
    # 创建集群命令
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

# 主函数
main() {
    echo "=== Redis Cluster Auto-Setup Script ==="
    echo "Install Path: $REDIS_HOME"
    echo ""
    
    # 检查节点状态
    if ! check_all_nodes; then
        echo "Not all Redis nodes are running. Cluster creation aborted."
        return 1
    fi
    
    echo ""
    echo "All nodes are running. Proceeding with cluster creation..."
    echo ""
    
    # 创建集群
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

# 执行主函数
main
