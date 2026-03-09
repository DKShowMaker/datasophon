#!/bin/bash

# Redis Cluster Auto Setup Script
# Automatically assign Slave nodes using --cluster-replicas 1

# All node addresses (Master and Worker)
ALL_NODES="${RedisMasterAddr} ${RedisSlaveAddr}"

# Redis installation path
REDIS_HOME="${redisInstallPath}/redis"

# Get the fixed leader node (first RedisWorker host)
get_cluster_leader_host() {
    echo "${RedisSlaveAddr}" | awk '{print $1}' | cut -d ":" -f 1
}

# Only the fixed leader should execute cluster create
is_local_cluster_leader() {
    leader_host=$(get_cluster_leader_host)
    if [ -z "$leader_host" ]; then
        echo "Error: No Redis worker host found for cluster leader."
        return 1
    fi

    local_host=$(hostname)
    local_fqdn=$(hostname -f 2>/dev/null || true)
    if [ "$local_host" = "$leader_host" ] || [ "$local_fqdn" = "$leader_host" ]; then
        return 0
    fi

    # Fallback: compare IP when leader host is configured as IP/FQDN
    leader_ip=$(getent hosts "$leader_host" 2>/dev/null | awk 'NR==1{print $1}')
    local_ips=$(hostname -I 2>/dev/null || true)
    if [ -n "$leader_ip" ] && [ -n "$local_ips" ] && echo "$local_ips" | grep -qw "$leader_ip"; then
        return 0
    fi
    return 1
}

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

# Check if cluster is already initialized
check_cluster_initialized() {
    first_master=$(echo "${RedisMasterAddr}" | awk '{print $1}')
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
    echo "Cluster Leader Host: $(get_cluster_leader_host)"
    echo ""

    if ! is_local_cluster_leader; then
        echo "Skip cluster creation on non-leader node."
        return 0
    fi
    
    # Check node status
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
