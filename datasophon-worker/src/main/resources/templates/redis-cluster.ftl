#!/bin/bash

# Redis Cluster Auto Setup Script
# Automatically assign Slave nodes using --cluster-replicas

# Redis installation path
REDIS_HOME="${redisInstallPath}/redis"

# Run mode: check | create
MODE=${"$"}{1:-create}
# Normalize and deduplicate host:port list
normalize_nodes() {
    echo "${RedisMasterAddr} ${RedisSlaveAddr}" | awk '{
        for (i = 1; i <= NF; i++) {
            if ($i != "" && !seen[$i]++) {
                print $i
            }
        }
    }'
}

# All node addresses (Master and Worker)
ALL_NODES=$(normalize_nodes | xargs)

count_address_nodes() {
    local addresses="$1"
    if [ -z "$addresses" ]; then
        echo 0
        return
    fi
    echo "$addresses" | awk '{print NF}'
}

get_first_master_node() {
    echo "${RedisMasterAddr}" | awk '{print $1}'
}

# Check if all nodes are running
check_all_nodes() {
    echo "Checking if all Redis nodes are running..."
    
    if [ -z "$ALL_NODES" ]; then
        echo "Error: ALL_NODES is empty."
        return 1
    fi
    
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

# Check if cluster is already initialized
check_cluster_initialized() {
    first_master=$(get_first_master_node)
    if [ -z "$first_master" ]; then
        return 1
    fi
    host=$(echo "$first_master" | cut -d ":" -f 1)
    port=$(echo "$first_master" | cut -d ":" -f 2)
    cluster_info=$($REDIS_HOME/bin/redis-cli -h $host -p $port cluster info 2>/dev/null || true)
    if echo "$cluster_info" | grep -q "cluster_state:ok"; then
        echo "Redis Cluster already initialized."
        return 0
    fi
    return 1
}

# Create cluster (auto-assign Slave)
create_cluster() {
    echo "Creating Redis Cluster with auto-assigned slaves..."
    echo "Nodes: $ALL_NODES"
    
    # Calculate --cluster-replicas value
    # If there are 3 Masters and 3 Slaves, then replica=1
    # Formula: slave count / master count
    MASTER_COUNT=$(count_address_nodes "${RedisMasterAddr}")
    SLAVE_COUNT=$(count_address_nodes "${RedisSlaveAddr}")
    
    if [ "$MASTER_COUNT" -eq 0 ]; then
        echo "Error: No master nodes found."
        return 1
    fi
    if [ "$MASTER_COUNT" -lt 3 ]; then
        echo "Error: Redis Cluster requires at least 3 master nodes, current: $MASTER_COUNT."
        return 1
    fi
    
    REPLICAS=$((SLAVE_COUNT / MASTER_COUNT))
    
    echo "Master count: $MASTER_COUNT"
    echo "Slave count: $SLAVE_COUNT"
    echo "Replicas per master: $REPLICAS"
    
    # Cluster creation command
    CREATE_CMD="$REDIS_HOME/bin/redis-cli --cluster create $ALL_NODES --cluster-replicas $REPLICAS --cluster-yes"
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
    echo "RedisMasterAddr: ${RedisMasterAddr}"
    echo "RedisSlaveAddr: ${RedisSlaveAddr}"
    echo "All nodes: $ALL_NODES"
    echo ""
    
    case "$MODE" in
        check)
            if ! check_all_nodes; then
                echo "Not all Redis nodes are running."
                return 1
            fi
            if check_cluster_initialized; then
                echo "Redis Cluster already initialized."
                return 0
            fi
            echo "All nodes are running and cluster is not initialized."
            return 0
            ;;
        create|*)
            if ! check_all_nodes; then
                echo "Not all Redis nodes are running. Cluster creation aborted."
                return 1
            fi
            if check_cluster_initialized; then
                echo "Skip cluster creation."
                return 0
            fi
            echo ""
            echo "All nodes are running. Proceeding with cluster creation..."
            echo ""
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
            ;;
    esac
}

# Execute main function
main
