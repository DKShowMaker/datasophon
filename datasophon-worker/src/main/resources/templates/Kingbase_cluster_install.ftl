## install.conf
## cluster deployment script configuration instructions:
##    path: in the same path as cluster_install.sh.
##    parameter: colud be set in the config file, also could be set in cluster_install.sh script(give priority to the configuration in this file).
##    constraints: 1. SSH encryption needs to be manually configured between the devices on which the script is run and the devices installed in the cluster, including between root users, ordinary users, root user and ordinary users.
##                 2. general-purpose computers can only be executed on ordinary users who are configured with SSH encryption, and BMJ can only be executed on root user, and all must be executed on the primary host.
##                 3. db.zip package decompression is completed at the directory level such as lib, bin, share, there can not be one more layer of directories in the middle, the directory like "kingbase/bin" can not be supported.
##                 4. automatic switching, automatic recovery, quorum syncgronization mode are enabled by default, scram-sha-256 cluster is enabled by default.

## instructions:
##     if you are currently in BMJ or deploy_by_sshd=0, you need to ensure that all hosts have successfully installed the database and that sys_securecmdd is in the startup state

######################################################################
# Required parameters
#####################################################################
[install]
## whether it is BMJ, if so, on_bmj=1, if not on_bmj=0, defaults to on_bmj=0
on_bmj=0

## the cluster node IP which needs to be deployed, is separated by spaces, for example:  all_ip=(192.168.1.10 192.168.1.11)
## or all_ip=(host1 host2)
## means deployed cluster of DG ==> ha_running_mode='DG'
all_ip=(${all_ip})

## only set if need to setup witness node in cluster. The value is the IP of witness node, for example: witness_ip="192.168.1.12"
## or witness_ip="host"
## it must be NULL when ha_running_mode='TPTC'
witness_ip=""

## the node IP will deployed in PRODUCTION, could not set it when all_ip is not NULL.
## the virtual_ip must be NULL, and auto_cluster_recovery_level will be 0.
## means deployed cluster of TPTC ==> ha_running_mode='TPTC'
## Cannot be configured as a domain name
production_ip=()

## the node IP will deployed in LOCAL DISASTER, could not be NULL if the production_ip is not NULL.
## Cannot be configured as a domain name
local_disaster_recovery_ip=()

## the node IP will deployed in REMOTE DISASTER, it could be NULL even the production_ip is not NULL.
## Cannot be configured as a domain name
remote_disaster_recovery_ip=()

## the path of cluster to be deployed, for example: install_dir="/home/kingbase/tmp_kingbase" [if it is BMJ, you do not need to configure this parameter]
## the directory structure after deployment:
##           ${install_dir}/kingbase/data                		the data directory
##           ${install_dir}/kingbase/archive             		log archive directory
##           ${install_dir}/kingbase/etc                 		configuration file directory
##           ${install_dir}/kingbase/bin、lib、share、log     	install file directory
## the last layer of directory could not add '/'
install_dir="${install_dir}"

## the absolute path of zip package, for example: zip_package="/home/kingbase/db.zip" [if it is BMJ or deploy_by_sshd=0, you do not need to configure this parameter]
## zip、tar and tar.gz package can be supported.
zip_package="/opt/datasophon/KingbaseESV8R6/Kingbase/cluster/db.zip"

## the name of license.dat [if it is BMJ or deploy_by_sshd=0, you do not need to configure this parameter]
## if there is no license file set, the default license file in zip_package will be read.
## if there are multiple license files, please write down all of them.
## make sure that the write order of license.dat file is the same as that of all_ip, if the same license file can be used in different devices, you can just write once.
## since the license file must named with "license.dat", if you have more than one license files, please use different name to distinguish them.
## example: license_file=(license.dat) or license_file=(license.dat-1 license.dat-2)
license_file=(license.dat)

# database initializes user configuration
db_user="${db_user}"                 # the user name of database
db_password="${db_password}"                  # the password of database.
db_port="${db_port}"                  # the port of database, defaults is 54321
db_mode="${db_mode}"                 # database mode: pg, oracle, mysql
db_auth="${db_auth}"          # database authority: scram-sha-256, md5, scram-sm3, sm4, default is scram-sha-256
db_case_sensitive="${db_case_sensitive}"          # database case sensitive settings: yes, no. default is yes - case sensitive; no - case insensitive
                                 # (NOTE. cannot set to 'no' when db_mode="pg", and cannot set to 'yes' when db_mode="mysql").
db_checksums="yes"               # the checksum for data: yes, no. default is yes - a checksum is calculated for each data block to prevent corruption; no - nothing to do.
archive_mode="on"                # enables archiving; off, on, or always

encoding="${encoding}"                  # set default encoding for new databases. must be one of ('default' 'UTF8' 'GBK' 'GB2312' 'GB18030')
locale="${locale}"             # set default locale for new databases.
                                 # +===============================================================================+
                                 # |  encoding  |  locale          |    initdb options                             |
                                 # +============+==================+===============================================+
                                 # |  default   |  *default        |    --lc-messages='C'                          |
                                 # +            +------------------+-----------------------------------------------+
                                 # |            |  C               |    --locale='C' --lc-messages='C'             |
                                 # +------------+------------------+-----------------------------------------------+
                                 # |            |  C               |    --locale='C' --lc-messages='C'             |
                                 # +            +------------------+-----------------------------------------------+
                                 # |   UTF8     |  *zh_CN.UTF-8    |    --locale='zh_CN.UTF-8' --lc-messages='C'   |
                                 # +            +------------------+-----------------------------------------------+
                                 # |            |  en_US.UTF-8     |    --locale='en_US.UTF-8' --lc-messages='C'   |
                                 # +------------+------------------+-----------------------------------------------+
                                 # |   GBK      |  C               |    --locale='C' --lc-messages='C'             |
                                 # +            +------------------+-----------------------------------------------+
                                 # |            |  *zh_CN.GBK      |    --locale='zh_CN.GBK' --lc-messages='C'     |
                                 # +------------+------------------+-----------------------------------------------+
                                 # |   GB2312   |  C               |    --locale='C' --lc-messages='C'             |
                                 # +            +------------------+-----------------------------------------------+
                                 # |            |  *zh_CN.GB2312   |    --locale='zh_CN.GB2312' --lc-messages='C'  |
                                 # +------------+------------------+-----------------------------------------------+
                                 # |   GB18030  |  C               |    --locale='C' --lc-messages='C'             |
                                 # +            +------------------+-----------------------------------------------+
                                 # |            |  *zh_CN.GB18030  |    --locale='zh_CN.GB18030' --lc-messages='C' |
                                 # +============+==================+===============================================+

other_db_init_options=""         # addional initdb options,such as "--scenario-tuning" (NOTE. cannot set --scenario-tuning when db_mode="mysql")
sync_security_guc="no"           # sync security GUC parameters in cluster (exclude witness): yes, no. default is no.
                                 # yes - for auto sync security GUC, create extension kdb_schedule and security_utils; no - nothing to do.

tcp_keepalives_idle="2"          # (integer; default: 7200; since Linux 2.2)
                                 # The  number  of  seconds  a  connection  needs to be idle before TCP begins sending out keep-alive counts.  Keep-alives are sent only when the
                                 # SO_KEEPALIVE socket option is enabled.  The default value is 7200 seconds (2 hours).  An idle connection is terminated after approximately  an
                                 # additional 11 minutes (9 counts an interval of 75 seconds apart) when keep-alive is enabled.	

tcp_keepalives_interval=""      # (integer; default: 75; since Linux 2.4)
                                 # The number of seconds between TCP keep-alive counts.

tcp_keepalives_count=""         # (integer; default: 9; since Linux 2.2)
                                 # The maximum number of TCP keep-alive counts to send before giving up and killing the connection if no response is obtained from the other end.
tcp_user_timeout="9000"          # (since Linux 2.6.37)
connection_timeout="10"          # connection timeout when use ssh or sys_securecmdd
wal_sender_timeout="30000"       # in milliseconds; 0 disables
wal_receiver_timeout="30000"     # time that receiver waits for
                                 # communication from master
                                 # in milliseconds; 0 disables


## the trust ip, which separated by English ',', and spaces are not allowed.
## For example: trusted_servers="192.168.28.1,192.168.29.1" or trusted_servers="host1,host2"
trusted_servers="${all_ip}"

## if failed to ping trusted_servers, the database can still be running? on, off. default is on - do nothing, the database will running; off - will stop the database.
running_under_failure_trusted_servers='on'

#####################################################################
# Optional parameters
#####################################################################

## Will or not use the data directory which is already exists on one node.
#  0: there is no data, will generate the data directory by initdb.
#  1: there is only one data, use it as the primary node. (In TPTC, the data directory must on any node of produtcion_ip.)
use_exist_data=0

## the path of data directory, BMJ defaults to "/opt/Kingbase/ES/V8/data", the general machine defaults to "install_dir/kingbase/data"
data_directory="${data_directory}"

## if seperate sys_wal from data directory, set the sys_wal location to waldir.
## the location should not be under the data directory
## the location should be an absolute path
## the waldir should be an empty path or nonexistent, initdb would create the location if it's nonexistent
waldir=''

## the vitural IP, for example: virtual_ip="192.168.28.188/24"
virtual_ip=""

## the net device, after configuring the vitural IP, net_device must been configured.
## please make sure that the writing order of net_device is the same as all_ip, if the net_device is the same, it should also be written together.
## do not need to consider net_device on witness node if configured witness_ip
## for example: net_device=(ens192 ens192) or net_device=(ens192 eth0)
net_device=()

## the net device ip, after configuring the vitural IP, net_device_ip must been configured.
## please make sure that the writing order of net_device_ip is the same as all_ip
## do not need to consider net_device_ip on witness node if configured witness_ip
## for example: net_device_ip=(10.10.11.128 10.10.11.129)
net_device_ip=()

## the path of ip, arping, ping command, defaults is /sbin or /bin
## by default, the arping_path is located in the bin directory of the database installation directory, if arping_path is null, then use default value.
## for example, if there is BMJ, arping_path=/opt/Kingbase/ES/V8/Server/bin
ipaddr_path="/sbin"
arping_path="/opt/datasophon/KingbaseESV8R6/Kingbase/cluster/kingbase/bin"
ping_path="/bin"

## super user, defaults is root
super_user="root"

## ordinary user, defaults is kingbase
execute_user="kingbase"

## other cluster parameters
deploy_by_sshd=0                # choose whether to use sshd when deploy, 0 means not to use (deploy by sys_securecmdd), 1 means to use (deploy by sshd), default value is 1; when on_bmj=1, it will auto set to no(deploy_by_sshd=0)
use_scmd=1                       # Is the cluster running on sys_securecmdd or sshd? 1 means yes (on sys_securecmdd), 0 means no (on sshd), default value is 1; when on_bmj=1, it will auto set to yes(use_scmd=1)
reconnect_attempts="10"          # the number of retries in the event of an error
reconnect_interval="6"           # retry interval
recovery="standby"               # the way of cluster recovery: standby/automatic/manual
ssh_port="22"                    # the port of ssh, default is 22
scmd_port="8890"                 # the port of sys_securecmdd, default is 8890

## ssl option, default value is '0', will not use ssl in cluster.
## set use_ssl=1 in database, and the cluster will use 'sslmode=require' to connect to database.
use_ssl=0

## all nodes failed recovery option, default value 1, do auto recovery when all nodes failed when network is OK and only one primary in cluster.
## 0 means disable the all fails recovery feature
## 2 means  max availability option,the cluster must contains two nodes and the trust server must be set, the recovery must be set to automatic.
auto_cluster_recovery_level='1'

## enable the disk check, default value is 'off', will do nothing when disk is error.
## if set to 'on', stop the database when disk is error.
use_check_disk='off'

## setting for kingbase synchronous_standby_names mode, values in "quorum\sync\all\async\custom"
##   quorum： the first do WAL replay standby can be sync node
##   sync:    the first standby in synchronous_standby_names, which connect to primary now, is sync node
##   all:     all the standbys in synchronous_standby_names, which connect to primary now, are sync node, and if there is no standby connect to primary, it is equal to async
##   async:   no standby is sync node
##   custom:  support for configuring the role of each node, and each node in the cluster must be assigned a role.
## For ha_running_mode='TPTC' the synchronous default value is 'all'.
## For ha_running_mode='DG', the synchronous default value is 'quorum'.
synchronous=''

## set nodes role as a sync nodes.
## the sync_nodes, which separated by English spaces.
## this parameter is only valid when synchronous is custom mode.
## the nodes in the sync_nodes parameter must all come from the all_ip parameter.
## for example:  synchrongous_nodes=(192.168.1.10 192.168.1.11 192.168.1.12)
## if the ha_running_mode is 'TPTC',sync_nodes are invalid.
sync_nodes=()

## set nodes role as a potential nodes.
## other rules are consistent with parameter sync_nodes.
potential_nodes=()

## set nodes role as a async nodes.
## other rules are consistent with parameter sync_nodes.
async_nodes=()

## For ha_running_mode='TPTC', if the sync nodes have the same location with primary ?
##    0:    some nodes could be sync nodes. (don't care what the location is)
##    1:    only the nodes have same location with primary, could be sync nodes.
## the default is 0. (when ha_running_mode='DG' or synchronous='async', this parameter has no effect)
sync_in_same_location=0

## For ha_running_mode='TPTC', if we can do failover when the standby node has different location with failure primary?
##    'off':  can not do failover, if the standby node has different location with primary.
##    'none': can do failover.
##    'any':  can do failover, need ANY server alive in primary's location if the standby node has different location with primary.
##    'all':  can do failover, need ALL servers alive in primary's location if the standby node has different location with primary.
## the default is off. (when ha_running_mode='DG', this parameter has no effect)
failover_need_server_alive='off'

## config of create a standby/witness node.
## when the cluster is in quorum or sync mode and expand sync standby node,
## it may automatically adjust synchronous_node and synchronous_standby_count parameters.
[expand]
expand_type=""                   # The node type of standby/witness node, which would be add to cluster. 0:standby  1:witness
primary_ip=""                    # The ip addr of cluster primary node, which need to expand a standby/witness node.
expand_ip=""                     # The ip addr of standby/witness node, which would be add to cluster.
node_id=""                       # The node_id of standby/witness node, which would be add to cluster. It does not the same with any one in  cluster node
                                 # for example: node_id="3"
sync_type=""                     # the sync_type parameter is used to specify the sync type for expand node. 0:sync 1:potential 2:async
                                 # this parameter is only valid when expand_type="0" and the synchronous parameter of the cluster is set to custom mode.

## Specific instructions ,see it under [install]
install_dir=""
zip_package=""
net_device=()                    # if virtual_ip set,it must be set
net_device_ip=()                 # if virtual_ip set,it must be set
license_file=()
deploy_by_sshd="1"
ssh_port="22"
scmd_port="8890"

## config of drop a standby/witness node
## when shrink a sync standby node,
## it may automatically adjust synchronous_node and synchronous_standby_count parameters.
[shrink]
shrink_type=""                   # The node type of standby/witness node, which would be delete from cluster. 0:standby  1:witness
primary_ip=""                    # The ip addr of cluster primary node, which need to shrink a standby/witness node.
shrink_ip=""                     # The ip addr of standby/witness node, which would be delete from cluster.
node_id=""                       # The node_id of standby/witness node, which would be delete from cluster. It does not the same with any one in  cluster node
                                 # for example: node_id="3"
## Specific instructions ,see it under [install]
install_dir=""
ssh_port="22"                    # the port of ssh, default is 22
scmd_port="8890"                 # the port of sys_securecmd, default isi 8890
