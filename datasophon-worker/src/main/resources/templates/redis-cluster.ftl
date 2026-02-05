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
    # If there are 3 Masters and 3 Slaves, then replica=1
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
