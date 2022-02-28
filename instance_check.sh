#!/bin/bash 
#####################
#   Hamed Maleki
#####################
DB_ADDRESS='192.168.10.10'
DB_USER='myuser'
DB_PASSWORD='mypassword'
DB_NAME='nagiosql'

instance_check()
{
PIDFILE=/tmp/.avai_insert.pid
if [ -e ${PIDFILE} ] && kill -0 `cat ${PIDFILE}` 2>/dev/null
then
  logger -p local1.error "Error: another instance of '$(basename $0)' is already running with PID (`cat ${PIDFILE}`). nothing to do ..."
  exit 1
else
echo $$ > ${PIDFILE}
fi
}


###### using function in action ######
instance_check

MYSQL="mysql -h $DB_ADDRESS -u $DB_USER -p$DB_PASSWORD --local-infile=1  $DB_NAME"
while read file
do 
$MYSQL -e "load data local infile '$file' into table availability fields terminated by ',' "
if [ $? -eq 0 ]
then 
rm -f $file 
fi
done < <(find /var/log/ping_result/ -mmin +1 | sort -n )
rm -f ${PIDFILE}
