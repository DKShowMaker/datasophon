bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisSlavePort}
logfile ${redisInstallPath}/redis/cluster/log/redis-slave.log
pidfile ${redisInstallPath}/redis/cluster/pid/redis-slave.pid
dir ${redisInstallPath}/redis/cluster
dbfilename dump-slave.rdb
appendonly yes
appendfilename appendonly-slave.aof

cluster-enabled yes
cluster-config-file ${redisInstallPath}/redis/cluster/conf/nodes-${redisSlavePort}.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
