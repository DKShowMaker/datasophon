bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisMasterPort}
logfile ${redisInstallPath}/redis/cluster/log/redis-master.log
pidfile ${redisInstallPath}/redis/cluster/pid/redis-master.pid
dir ${redisInstallPath}/redis/cluster
dbfilename dump-master.rdb
appendonly yes
appendfilename appendonly-master.aof

cluster-enabled yes
cluster-config-file ${redisInstallPath}/redis/cluster/conf/nodes-${redisMasterPort}.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
