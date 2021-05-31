#!/bin/bash

#Author: kreicer
#Version: 0.8
#Requirements: jq, xmllint (apt-get install jq libxml2-utils)

div="oIo"
statuses=${1//$div/ }
zabbixconf="/etc/zabbix/zabbix_agentd.d/"
xmlpath="/tmp/fpm-monitoring.xml"
outpath="/tmp/fpmstat.txt"

case $2 in
	discovery)
		echo '{"data":['
		for statuspage in $statuses; do
			curl -s "$statuspage?json" | jq '.pool' | awk '{print "{\"{#POOL}\":"$0"},"}'
		done | sed '$ s/.$//'
		echo ']}'
		;;
	data)
		cat /dev/null > $outpath
		
		for statuspage in $statuses; do
			curl -s "$statuspage?xml" > $xmlpath
		
			pool=$(xmllint --xpath '/status/pool/text()' $xmlpath)
			
			manager=$(xmllint --xpath '/status/process-manager/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,manager] $manager" >> $outpath
			
			start_time=$(xmllint --xpath '/status/start-time/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,start_time] $start_time" >> $outpath
			
			start_since=$(xmllint --xpath '/status/start-since/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,start_since] $start_since" >> $outpath
			
			acc_conn=$(xmllint --xpath '/status/accepted-conn/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,acc_conn] $acc_conn" >> $outpath
			
			lsn_queue=$(xmllint --xpath '/status/listen-queue/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,lsn_queue] $lsn_queue" >> $outpath
			
			max_queue=$(xmllint --xpath '/status/max-listen-queue/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,max_queue] $max_queue" >> $outpath
			
			len_queue=$(xmllint --xpath '/status/listen-queue-len/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,len_queue] $len_queue" >> $outpath
			
			idle_proc=$(xmllint --xpath '/status/idle-processes/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,idle_proc] $idle_proc" >> $outpath
			
			act_proc=$(xmllint --xpath '/status/active-processes/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,act_proc] $act_proc" >> $outpath
			
			tot_proc=$(xmllint --xpath '/status/total-processes/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,tot_proc] $tot_proc" >> $outpath
			
			max_proc=$(xmllint --xpath '/status/max-active-processes/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,max_proc] $max_proc" >> $outpath
			
			max_chil=$(xmllint --xpath '/status/max-children-reached/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,max_chil] $max_chil" >> $outpath
			
			slow_req=$(xmllint --xpath '/status/slow-requests/text()' $xmlpath)
			echo "$3 fpm[$2,$pool,slow_req] $slow_req" >> $outpath	
		done		
		
		zabbix_sender -c $zabbixconf -i $outpath &>/dev/null
		date
		;;
	*) 
		echo "Usage: ./fpm-monitoring.sh [statuspage address(es)] [discovery|data] [if data: host for receiving info]"
		;;
esac
