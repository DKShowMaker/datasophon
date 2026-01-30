#!/bin/bash

user=dmdba
groupname=dinstall
groupid=2001
password="xiaofang@2019"

if [ -d ${INSTALL_PATH} ];then
    cd ${INSTALL_PATH}/bin
    ./DmService${INSTANCE_NAME} start
    exit 0
fi

#create group if not exists
cat /etc/group | grep $groupname
if [ $? -ne 0 ]
then
    echo "create group $groupname $groupid"
    groupadd -g $groupid $groupname
else
    echo "group $groupname already exists"
fi

#create user if not exists
cat /etc/group | grep $user
if [ $? -ne 0 ]
then
    echo "add user $user"
    useradd  -G $groupname -m -d /home/dmdba -s /bin/bash -u $groupid $user

    echo "$user:$password" | chpasswd
    echo "passwd is $password"
else
    echo "user $user already exists"
fi


echo "start decompressing"
mkdir -p ${INSTALL_PATH}
chown -R $user:$groupname ${INSTALL_PATH}
chmod -R 755 ${INSTALL_PATH}

cd /opt/datasophon/dm8

echo "start set up arguments"
sed -ri "s|(<INSTALL_TYPE>).*(</INSTALL_TYPE>)|\1${INSTALL_TYPE}\2|g" auto_install.xml
sed -ri "s|(<INSTALL_PATH>).*(</INSTALL_PATH>)|\1${INSTALL_PATH}\2|g" auto_install.xml
sed -ri "s|(<INIT_DB>).*(</INIT_DB>)|\1${INIT_DB}\2|g" auto_install.xml
sed -ri "s|(<PORT_NUM>).*(</PORT_NUM>)|\1${PORT_NUM}\2|g" auto_install.xml
sed -ri "s|(<PATH>).*(</PATH>)|\1${PATH}\2|g" auto_install.xml
sed -ri "s|(<DB_NAME>).*(</DB_NAME>)|\1${DB_NAME}\2|g" auto_install.xml
sed -i "s/dbname/${DB_NAME}/g" auto_install.xml
sed -ri "s|(<INSTANCE_NAME>).*(</INSTANCE_NAME>)|\1${INSTANCE_NAME}\2|g" auto_install.xml
sed -ri "s|(<EXTENT_SIZE>).*(</EXTENT_SIZE>)|\1${EXTENT_SIZE}\2|g" auto_install.xml
sed -ri "s|(<PAGE_SIZE>).*(</PAGE_SIZE>)|\1${PAGE_SIZE}\2|g" auto_install.xml
sed -ri "s|(<LOG_SIZE>).*(</LOG_SIZE>)|\1${LOG_SIZE}\2|g" auto_install.xml
sed -ri "s|(<CASE_SENSITIVE>).*(</CASE_SENSITIVE>)|\1${CASE_SENSITIVE}\2|g" auto_install.xml
sed -ri "s|(<CHARSET>).*(</CHARSET>)|\1${CHARSET}\2|g" auto_install.xml
sed -ri "s|(<SYSDBA_PWD>).*(</SYSDBA_PWD>)|\1${SYSDBA_PWD}\2|g" auto_install.xml
sed -ri "s|(<SYSAUDITOR_PWD>).*(</SYSAUDITOR_PWD>)|\1${SYSAUDITOR_PWD}\2|g" auto_install.xml
sed -ri "s|(<SYSSSO_PWD>).*(</SYSSSO_PWD>)|\1${SYSSSO_PWD}\2|g" auto_install.xml
sed -ri "s|(<SYSDBO_PWD>).*(</SYSDBO_PWD>)|\1${SYSDBO_PWD}\2|g" auto_install.xml
sed -ri "s|(<CREATE_DB_SERVICE>).*(</CREATE_DB_SERVICE>)|\1${CREATE_DB_SERVICE}\2|g" auto_install.xml
sed -ri "s|(<STARTUP_DB_SERVICE>).*(</STARTUP_DB_SERVICE>)|\1${STARTUP_DB_SERVICE}\2|g" auto_install.xml

echo "start install"
export DM_INSTALL_TMPDIR=/home/dmdba/tmp
if [ ! -d "$DM_INSTALL_TMPDIR" ];then
    mkdir /home/dmdba/tmp
fi

./DMInstall.bin -q /opt/datasophon/dm8/auto_install.xml

if [ $? -ne 0 ]; then
    echo "达梦安装失败"
    exit 1
fi


#add path
grep 'export PATH=$PATH:$DM_HOME' /root/.bash_profile
if [ $? -ne 0 ]; then
    echo "export LD_LIBRARY_PATH=\"${INSTALL_PATH}/bin\"" >> /root/.bash_profile
    echo "export DM_HOME=\"${INSTALL_PATH}\"" >> /root/.bash_profile
    echo 'export PATH=$PATH:$LD_LIBRARY_PATH' >> /root/.bash_profile
    echo 'export PATH=$PATH:$DM_HOME' >> /root/.bash_profile
    source /root/.bash_profile
fi

# db_monitor
cd /opt/datasophon/dmdb/etc/
echo "dbHost=127.0.0.1:${PORT_NUM}?autoCommit=true" > dameng_exporter.config
echo "dbUser=SYSDBA" >> dameng_exporter.config
echo "dbPwd=${SYSDBA_PWD}" >> dameng_exporter.config
./dameng_exporter > dameng_exporter.log

#日志重定向
cd ${INSTALL_PATH}/log
sh /opt/datasophon/dm8/bin/log_monitor.sh > /opt/datasophon/dm8/bin/log_monitor.log &

if sh /opt/datasophon/dm8/bin/status.sh; then 
    echo "达梦数据库安装成功"
else 
    sleep 10
    cd ${INSTALL_PATH}/bin
    ./DmService${INSTANCE_NAME} start
fi