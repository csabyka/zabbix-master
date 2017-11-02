#!/bin/bash
### OPTIONS VERIFICATION
if [[ -z "$1" || -z "$2" || -z "$3" ]]; then exit 1; fi
##### PARAMETERS #####
RESERVED="$1"
METRIC="$2"
STATSURL="$3"
#
CURL="/usr/bin/curl"
TTLCACHE="55"
FILECACHE="/tmp/zabbix.nginx-stats.cache"
TIMENOW=`date '+%s'`
##### RUN #####

if [ -s "$FILECACHE" ]; then TIMECACHE=`stat -c"%Z" "$FILECACHE"`; else TIMECACHE=0; fi

if [ "$(($TIMENOW - $TIMECACHE))" -gt "$TTLCACHE" ]; then 
     echo "" >> $FILECACHE
     DATACACHE=`$CURL --insecure -s "$STATSURL"` || exit 1
     echo "$DATACACHE" > $FILECACHE # !!!
fi

case "$METRIC" in
 "active")   active=`cat $FILECACHE | grep Active | awk '{print $3}'`
             if [ "$active" ]; then echo "$active"; else echo "0"; fi
             ;;
 "accepts")  accepts=`cat $FILECACHE | sed -n '3p' | awk '{print $1}'`
             if [ "$accepts" ]; then echo "$accepts"; else echo "0"; fi
             ;;
 "handled")  handled=`cat $FILECACHE | sed -n '3p' | awk '{print $2}'`
             if [ "$handled" ]; then echo "$handled"; else echo "0"; fi
             ;;
 "requests") requests=`cat $FILECACHE | sed -n '3p' | awk '{print $3}'`
             if [ "$requests" ]; then echo "$requests"; else echo "0"; fi
             ;;
 "reading")  reading=`cat $FILECACHE | grep Reading | awk '{print $2}'`
             if [ "$reading" ]; then echo "$reading"; else echo "0"; fi
             ;;
 "writing")  writing=`cat $FILECACHE | grep Writing | awk '{print $4}'`
             if [ "$writing" ]; then echo "$writing"; else echo "0"; fi
             ;;
 "waiting")  waiting=`cat $FILECACHE | grep Waiting | awk '{print $6}'`
             if [ "$waiting" ]; then echo "$waiting"; else echo "0"; fi
             ;;
 *)          ;;
esac

exit 0
