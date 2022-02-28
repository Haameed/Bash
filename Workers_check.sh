#!/bin/bash
#############
#  Author: Hamed Maleki
#       V 1.0 : list hostgroups on each workers 
#       V 1.1 : adding ability to show number of nodes, host checks, service check  on each workers
#############

MYSQL="/usr/bin/mysql -BN -usomeuser -p'somepassword' nagiosql"
OUT_PUT="/tmp/workers.log"
NAGIOS_MAIN='b2b-monitoring.mobinnet.net'


if [[ ! -z $1 ]] && [[ "w$1" == "w-r" ]]
then 
truncate -s0 $OUT_PUT  2>$1 > /dev/null
echo -e "LAST_UPDATE=$(date +"%F %T")" >> $OUT_PUT
echo -e "\033[0;33m\tHOST_NAME\tIP_Address\tHOSTS\tSERVICES\tCHECKS\tTotal Mem MB\tUsed Mem MB\tFree Mem MB\tBufferd Mem MB\tLoad AVG 15 min\t\033[m"  >> $OUT_PUT
for i in $($MYSQL -e 'select address from workers order by address') 
do 
MEM_INFO=$(echo dummy | ssh $i "free -m | grep Mem | awk '{print \$2, \$3, \$4,\$6}'")
TOTAL_MEM=$(echo $MEM_INFO | awk '{print $1}')
USED_MEM=$(echo $MEM_INFO | awk '{print $2}')
FREE_MEM=$(echo $MEM_INFO | awk '{print $3}')
BUFF_MEM=$(echo $MEM_INFO | awk '{print $4}')
LOAD_AVG=$(echo dummy | ssh $i "uptime | awk '{print \$NF}'")
HOST_NAME=$($MYSQL -e "select host_name from workers where address = '$i'")
COUNT_HOST_MEMBERS=$($MYSQL -e "select count(id) from tbl_host where active = '1' and id in (select idmaster from tbl_lnkHostToVariabledefinition where idslave in (select id from tbl_variabledefinition where name = '_WORKER' and value = 'hostgroup_${HOST_NAME}'))")
COUNT_SERVICE_MEMBERS=$($MYSQL -e "select count(id) from tbl_service where active = '1' and config_name in (select host_name from tbl_host where id in (select idmaster from tbl_lnkHostToVariabledefinition where idslave in (select id from tbl_variabledefinition where name = '_WORKER' and value = 'hostgroup_${HOST_NAME}'))) and id not in (select idMaster from tbl_lnkServiceToServicetemplate where idSlave in (select id from tbl_servicetemplate where template_name = 'intranet_services'))")
CHECKS=$(expr $COUNT_HOST_MEMBERS + $COUNT_SERVICE_MEMBERS )
echo -e "\033[0;37m\t$HOST_NAME\t$i\t$COUNT_HOST_MEMBERS\t$COUNT_SERVICE_MEMBERS\t$CHECKS\t$TOTAL_MEM\t$USED_MEM\t$FREE_MEM\t$BUFF_MEM\t$LOAD_AVG\t\033[m" >> $OUT_PUT
done 
TOTAL_HOSTS=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$4}  END {print a}')
TOTAL_SERVICES=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$5}  END {print a}')
TOTAL_CHECKS=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$6}  END {print a}')
TOTAL_MEMORY=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$7}  END {printf "%.2f\n", a/1024}')
TOTAL_USED=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$8}  END {printf "%.2f\n", a/1024}')
TOTAL_FREE=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$9}  END {printf "%.2f\n", a/1024}')
TOTAL_BUFFERD=$(cat $OUT_PUT | grep -v -e LAST_UPDATE -e HOST_NAME | grep -v Total | awk -F $'\t' '{a+=$10}  END {printf "%.2f\n", a/1024}')
echo -e "\033[1;31m\tTotal\t\t$TOTAL_HOSTS\t$TOTAL_SERVICES\t$TOTAL_CHECKS\t$TOTAL_MEMORY GB\t$TOTAL_USED GB\t$TOTAL_FREE GB\t$TOTAL_BUFFERD GB\t\t\033[m" >> $OUT_PUT
scp $OUT_PUT  root@${NAGIOS_MAIN}:$OUT_PUT 2>&1 > /dev/null
else
LAST_UPDATE=$(cat $OUT_PUT |grep LAST_UPDATE | awk -F '=' '{print $2}')
echo -e "\r"
echo -e "\033[1;32m\t\t\t\t\t\t\t\t-------------------------------------\033[m"
echo -e "\033[1;32m\t\t\t\t\t\t\t\t\033[1;32m| Last update = $LAST_UPDATE |\033[m"
echo -e "\033[1;32m\t\t\t\t\t\t\t\t-------------------------------------\033[m"
echo -e "\r"
cat $OUT_PUT |grep -v LAST_UPDATE |  column -t -s $'\t' -o '  |  ' 
echo -e "\r"
fi
