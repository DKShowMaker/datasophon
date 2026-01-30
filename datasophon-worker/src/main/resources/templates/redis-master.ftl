bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisMasterPort}
logfile "/opt/datasophon/redis/cluster/log/cluster-master.log"
pidfile /opt/datasophon/redis/cluster/pid/cluster-master.pid
dir /opt/datasophon/redis/cluster
dbfilename dump-master.rdb
appendonly yes
appendfilename "appendonly-master.aof"

cluster-enabled yes
cluster-config-file /opt/datasophon/redis/cluster/conf/nodes-master.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
