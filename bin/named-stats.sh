#!/bin/bash
# oev <offer4job@outlook.com>; 27.01.2017

if [[ -z "$1" ]]; then exit 1; fi

RNDC_BIN=/usr/sbin/rndc
STATS='/var/named/data/named_stats.txt'
METRIC="$1"

rm -f $STATS
if ! $RNDC_BIN stats; then exit 1; fi

if [ -s ${STATS} ]; then

    named_total_query=$(awk '/ QUERY/ {print $1}' $STATS)
    named_ipv4_request=$(awk '/ IPv4 requests received/ {print $1}' $STATS)
    named_tcp_request=$(awk '/ TCP requests received/ {print $1}' $STATS)
    named_total_response=$(awk '/[0-9] responses sent/ {print $1}' $STATS)
    named_success_query=$(awk '/queries resulted in successful/ {print $1}' $STATS)
    named_dropped_query=$(awk '/ queries dropped/ {print $1}' $STATS)

case "$METRIC" in
  "named_total_query")    if ! [ -z $named_total_query ]; then echo $named_total_query; else echo 0; fi
                          ;;
  "named_ipv4_request")   if ! [ -z $named_ipv4_request ]; then echo $named_ipv4_request; else echo 0; fi
                          ;;
  "named_tcp_request")    if ! [ -z $named_tcp_request ]; then echo $named_tcp_request; else echo 0; fi
                          ;;
  "named_total_response") if ! [ -z $named_total_response ]; then echo $named_total_response; else echo 0; fi
                          ;;
  "named_success_query")  if ! [ -z $named_success_query ]; then echo $named_success_query; else echo 0; fi
                          ;;
  "named_dropped_query")  if ! [ -z $named_dropped_query ]; then echo $named_dropped_query; else echo 0; fi
                          ;;
  *) ;;
esac

elif tty >/dev/null ; then
    echo "${STATS} does not exist!" >&2
    exit 1
fi

exit 0

