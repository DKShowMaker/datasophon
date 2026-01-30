bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisSlavePort}
logfile "/opt/datasophon/redis/cluster/log/cluster-slave.log"
pidfile /opt/datasophon/redis/cluster/pid/cluster-slave.pid
dir /opt/datasophon/redis/cluster
dbfilename dump-slave.rdb
appendonly yes
appendfilename "appendonly-slave.aof"

cluster-enabled yes
cluster-config-file /opt/datasophon/redis/cluster/conf/nodes-slave.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
