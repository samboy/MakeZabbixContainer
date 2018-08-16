#!/bin/sh

# Just in case
docker stop $(docker ps -q) ; docker rm $(docker ps -a -q)

# Observe: This is a *BASE* CentOS 7 system.  Factory default.
DOCKERID=$( docker run -p 8080:80 -dit centos:7 bash )

# First things first: Security updates (usually Docker is up to date
# with these, but if we run a local repo, we may not be)
docker exec -it $DOCKERID \
yum -y update
docker exec -it $DOCKERID \
yum -y install net-tools
docker exec -it $DOCKERID \
yum -y install less

# Add a MySQL server
docker exec -it $DOCKERID \
yum -y install mariadb-server # By Any Other Name

docker exec -it $DOCKERID \
mysql_install_db

docker exec -it $DOCKERID \
chown -R mysql:mysql /var/lib/mysql/

# Docker CentOS7 has issues with "service" command, so we start mysqld
# manually 
docker exec $DOCKERID \
/usr/bin/mysqld_safe --basedir=/usr --nowatch

# CentOS docker annoyance: Docs not installed
# Yes, the initial setup should not be under "doc" for Zabbix, but it is.
docker exec $DOCKERID \
sed -i '/excludedocs/d' /etc/rpm/macros.imgcreate
docker exec $DOCKERID \
sed -i '/nodocs/d' /etc/yum.conf

#### INSTALL ZABBIX ####

# This is current as of 2018-08-15
docker exec -it $DOCKERID \
rpm -i https://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm 

# Install base Zabbix
docker exec -it $DOCKERID \
yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent 

# Set Zabbix time zone
docker exec -it $DOCKERID \
sed -i 's/\# php/php/' /etc/httpd/conf.d/zabbix.conf
docker exec -it $DOCKERID \
sed -i 's/Europe\/Riga/US\/Pacific/' /etc/httpd/conf.d/zabbix.conf

# Set up mysql database for Zabbix
cat > setup.mysql.sh << EOF
#!/bin/sh

echo 'create database zabbix character set utf8 collate utf8_bin;' | mysql -u root
echo "grant all privileges on zabbix.* to zabbix@localhost identified by 'foo';" | mysql -u root
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -pfoo zabbix
echo DBPassword=foo >> /etc/zabbix/zabbix_server.conf
/usr/sbin/zabbix_server -c /etc/zabbix/zabbix_server.conf
sleep 5
/usr/sbin/zabbix_agentd -c /etc/zabbix/zabbix_agentd.conf
sleep 5
httpd
sleep 20
EOF

docker cp setup.mysql.sh $DOCKERID:/
docker exec -it $DOCKERID \
bash /setup.mysql.sh

# At this point, I used the web interface to make the following file:
cat > zabbix.conf.php << EOF
<?php
// Zabbix GUI configuration file.
global $DB;

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '0';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = 'foo';

// Schema name. Used for IBM DB2 and PostgreSQL.
$DB['SCHEMA'] = '';

$ZBX_SERVER      = 'localhost';
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = '';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
EOF

docker cp zabbix.conf.php $DOCKERID:/etc/zabbix/web/

