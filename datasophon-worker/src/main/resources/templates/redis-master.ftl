bind 0.0.0.0
daemonize yes
protected-mode no
port ${redisMasterPort}
logfile "${INSTALL_PATH}/cluster/log/cluster-master.log"
pidfile ${INSTALL_PATH}/cluster/pid/cluster-master.pid
dir ${INSTALL_PATH}/cluster
dbfilename dump-master.rdb
appendonly yes
appendfilename "appendonly-master.aof"

cluster-enabled yes
cluster-config-file ${INSTALL_PATH}/cluster/conf/nodes-master.conf
cluster-node-timeout 5000

<#list itemList as item>
${item.name} ${item.value}
</#list>
