#!/bin/bash

# Import configuration file
source /etc/bareos/bareos-zabbix.conf

# Get Job ID from parameter
bareosJobId="$1"
if [ -z $bareosJobId ] ; then exit 3 ; fi

# Test if zabbix_sender exists and execute permission is granted, if not, exit
if [ ! -x $zabbixSender ] ; then exit 5 ; fi

# Chose which database command to use
case $bareosDbSgdb in
  P) sql="/usr/bin/psql -h$bareosDbAddr -p$bareosDbPort -U$bareosDbUser -d$bareosDbName -tA -c" ;;
  M) sql="/usr/bin/mysql -NB -h$bareosDbAddr -P$bareosDbPort -u$bareosDbUser -p$bareosDbPass -D$bareosDbName -e" ;;
  *) exit 7 ;;
esac

# Get Job type from database, then if it is a backup job, proceed, if not, exit
bareosJobType=$($sql "select Type from Job where JobId=$bareosJobId;" 2>/dev/null)

if [ "$bareosJobType" != "B" ] ; then exit 9 ; fi


# Get Job level from database and classify it as Full, Differential, or Incremental
bareosJobLevel=$($sql "select Level from Job where JobId=$bareosJobId;" 2>/dev/null)
case $bareosJobLevel in
  'F') level='full' ;;
  'D') level='diff' ;;
  'I') level='incr' ;;
  *)   exit 11 ;;
esac


# Get Job exit status from database and classify it as OK, OK with warnings, or Fail
bareosJobStatus=$($sql "select JobStatus from Job where JobId=$bareosJobId;" 2>/dev/null)
if [ -z $bareosJobStatus ] ; then exit 13 ; fi
case $bareosJobStatus in
  "T") status=0 ;;
  "W") status=1 ;;
  *)   status=2 ;;
esac

# Get client's name from database
bareosClientName=$($sql "select Client.Name from Client,Job where Job.ClientId=Client.ClientId and Job.JobId=$bareosJobId;" 2>/dev/null)
if [ -z $bareosClientName ] ; then exit 15 ; fi

# Get Jobs's name from database
bareosJobName=$($sql "select name from Job where Job.JobId=$bareosJobId;")
if [ -z $bareosJobName ] ; then exit 15 ; fi


# Initialize return as zero
return=0

# Send Job exit status to Zabbix server
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s  $bareosClientName -k "bareos.$level.job.status[$bareosJobName]" -o $status >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+1)) ; fi

# Get from database the number of bytes transferred by the Job and send it to Zabbix server
bareosJobBytes=$($sql "select JobBytes from Job where JobId=$bareosJobId;" 2>/dev/null)
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s  $bareosClientName -k "bareos.$level.job.bytes[$bareosJobName]" -o $bareosJobBytes >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+2)) ; fi

# Get from database the number of files transferred by the Job and send it to Zabbix server
bareosJobFiles=$($sql "select JobFiles from Job where JobId=$bareosJobId;" 2>/dev/null)
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s $bareosClientName -k "bareos.$level.job.files[$bareosJobName]" -o $bareosJobFiles >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+4)) ; fi

# Get from database the time spent by the Job and send it to Zabbix server

case $bareosDbSgdb in
  M) bareosJobTime=$($sql "select timestampdiff(second,StartTime,EndTime) from Job where JobId=$bareosJobId;" 2>/dev/null);;
  P) bareosJobTime=$($sql "select EXTRACT(epoch from (EndTime-StartTime)) from Job where JobId=$bareosJobId;" 2>/dev/null);;
esac
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s $bareosClientName -k "bareos.$level.job.time[$bareosJobName]" -o $bareosJobTime >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+8)) ; fi

# Get Job speed from database and send it to Zabbix server
case $bareosDbSgdb in
  M) bareosJobSpeed=$($sql "select round(JobBytes/timestampdiff(second,StartTime,EndTime)) from Job where JobId=$bareosJobId;" 2>/dev/null);;
  P) bareosJobSpeed=$($sql "select round(JobBytes/EXTRACT(epoch from (EndTime-StartTime))) from Job where JobId=$bareosJobId;" 2>/dev/null);;
esac
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s $bareosClientName -k "bareos.$level.job.speed[$bareosJobName]" -o $bareosJobSpeed >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+16)) ; fi

# Get Job compression rate from database and send it to Zabbix server
bareosJobCompr=$($sql "select round(1-JobBytes/ReadBytes,2) from Job where JobId=$bareosJobId;" 2>/dev/null)
$zabbixSender -z $zabbixSrvAddr -p $zabbixSrvPort -s $bareosClientName -k "bareos.$level.job.compr[$bareosJobName]" -o $bareosJobCompr >/dev/null 2>&1
if [ $? -ne 0 ] ; then return=$(($return+32)) ; fi

# Exit with return status
exit $return
