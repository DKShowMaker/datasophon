bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisSlavePort}
logfile "${INSTALL_PATH}/cluster/log/cluster-slave.log"
pidfile ${INSTALL_PATH}/cluster/pid/cluster-slave.pid
dir ${INSTALL_PATH}/cluster
dbfilename dump-slave.rdb
appendonly yes
appendfilename "appendonly-slave.aof"

cluster-enabled yes
cluster-config-file ${INSTALL_PATH}/cluster/conf/nodes-slave.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
