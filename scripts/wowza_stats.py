#!/usr/bin/python

import os
import sys
import argparse
import time
import xmltodict
import re
import base64
import requests
from requests.auth import HTTPDigestAuth

parser = argparse.ArgumentParser(description='Zabbix Wowza client')

parser.add_argument('-a', '--address', dest='server_address', help='Host or IP', required=True)
parser.add_argument('-u', '--user', dest='username', help='Wowza User', required=True)
parser.add_argument('-p', '--pass', dest='password', help='Wowza Pass', required=True)
parser.add_argument('-q', '--query', dest='query', help='Zabbix Discovery (opt: vhost for vhosts, app vhosts&apps')
parser.add_argument('-k', '--key', dest='zkey', help='Counter to get')
parser.add_argument('-t', '--ttl', dest='ttl', help='Local cache TTL', default=295)
parser.add_argument('-V', '--VHost', dest='vhost', help='Optional: vhost name')
parser.add_argument('-A', '--Application', dest='application', help='Optional: application name')
parser.add_argument('-v', '--verbose', action='count', dest='verbose', help='Be verbose')

args = parser.parse_args()

def get_stats():
  filepath = "/tmp/wowza_stats.xml"

  if args.verbose:
    if os.path.exists(filepath):
      print "Cache file exists:", filepath
      print "Cache is %s seconds old" % str(time.time()-os.stat(filepath)[8])

  if not os.path.exists(filepath) or int(time.time()-os.stat(filepath)[8]) > int(args.ttl):
    # Get data from the server
    response = requests.get('http://'+args.server_address+':8086/connectioncounts/', auth=HTTPDigestAuth(args.username, args.password))
    text = response.text
    f = open(filepath, 'w')
    f.write(text)
  else:
    f = open(filepath, 'r')
    text = f.read()

  return text

def query_vhosts():
  data = get_stats()
  
  xmldata = xmltodict.parse(data)

  returndata = '{ "data":['

  if 'Name' in xmldata['WowzaStreamingEngine']['VHost']:
    vhost = xmldata['WowzaStreamingEngine']['VHost']['Name']
    if args.verbose:
      print "Only 1 Vhost found:",vhost
      
    returndata += '{ "{#WOWZAVHOST}":"'+vhost+'" }'
    
  else:
    first = True
    for i in range(len(xmldata['WowzaStreamingEngine']['VHost'])):
      vhost = xmldata['WowzaStreamingEngine']['VHost'][i]['Name']
      if args.verbose:
        print "Vhost:",vhost
      if first:
        returndata += '{ "{#WOWZAVHOST}":"'+vhost+'" }'
        first = False
      else:
        returndata += ',{ "{#WOWZAVHOST}":"'+vhost+'" }'
        
  returndata += '] }'
  return returndata    

def query_all():
  data = get_stats()

  xmldata = xmltodict.parse(data)

  returndata = '{ "data":['

  if 'Name' in xmldata['WowzaStreamingEngine']['VHost']:
    vhost = xmldata['WowzaStreamingEngine']['VHost']['Name']
    if args.verbose:
      print "Only 1 Vhost found:",vhost

    if 'Name' in xmldata['WowzaStreamingEngine']['VHost']['Application']:
      application = xmldata['WowzaStreamingEngine']['VHost']['Application']['Name']
      if args.verbose:
        print "Only 1 Application found:",application

      returndata += '{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'

    else:
      first = True
      for i in range(len(xmldata['WowzaStreamingEngine']['VHost']['Application'])):
        application = xmldata['WowzaStreamingEngine']['VHost']['Application'][i]['Name']
        if args.verbose:
          print "Application:",application
        
        if first:
          returndata += '{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'
          first=False
        else:
          returndata += ',{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'
        
  
  else:
    first = True
    for i in range(len(xmldata['WowzaStreamingEngine']['VHost'])):
      vhost = xmldata['WowzaStreamingEngine']['VHost'][i]['Name']
      if args.verbose:
        print "Vhost:",vhost
      
      if 'Name' in xmldata['WowzaStreamingEngine']['VHost'][i]['Application']:
        application = xmldata['WowzaStreamingEngine']['VHost'][i]['Application']['Name']
        if args.verbose:
          print "Only 1 Application found:",application

        if first:
          returndata += '{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'
          first = False
        else:
          returndata += ',{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'

      else:
        for j in range(len(xmldata['WowzaStreamingEngine'][i]['VHost']['Application'])):
          application = xmldata['WowzaStreamingEngine'][i]['VHost']['Application'][j]['Name']
          if args.verbose:
            print "Application:",application

          if first:
            returndata += '{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'
            first = False
          else:
            returndata += ',{ "{#WOWZAVHOST}":"'+vhost+'","{#WOWZAAPP}":"'+application+'" }'

  returndata += '] }'
  return returndata

def get_data():
  data = get_stats()
  
  xmldata = xmltodict.parse(data)

  key = ''

  if args.application:
    if args.vhost:
      if 'Name' in xmldata['WowzaStreamingEngine']['VHost']:
        if args.verbose:
          print "Only 1 Vhost found:",xmldata['WowzaStreamingEngine']['VHost']['Name']
        
        if 'Name' in xmldata['WowzaStreamingEngine']['VHost']['Application']:
          # Collect key stats here for vhost and application
          if args.verbose:
            print "Only 1 Application found:",xmldata['WowzaStreamingEngine']['VHost']['Application']['Name']

          val = xmldata['WowzaStreamingEngine']['VHost']['Application'][args.zkey]
          if args.zkey == "Status":
            key = val
          else:
            m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
            if m:
              key = float(m.group(0))*(10**float(m.group(1)))
            else:
              key = float(val)

        else:
          # collect key stats here for vhost and application[Name]
          for i in range(len(xmldata['WowzaStreamingEngine']['VHost']['Application'])):
            if args.verbose:
              print "Application:",xmldata['WowzaStreamingEngine']['VHost']['Application'][i]['Name']
            if args.application == xmldata['WowzaStreamingEngine']['VHost']['Application'][i]['Name']:
              if args.verbose:
                print "found App",args.application
              val = xmldata['WowzaStreamingEngine']['VHost']['Application'][i][args.zkey]
              if args.zkey == "Status":
                key = val
              else:
                m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
                if m:
                  key = float(m.group(0))*(10**float(m.group(1)))
                else:
                  key = float(val)
      else:
        # Multiple vhosts, find the right one.
        for i in range(len(xmldata['WowzaStreamingEngine']['VHost'])):
          if args.verbose:
            print "Vhost:",xmldata['WowzaStreamingEngine']['VHost'][i]['Name']
            if args.vhost == xmldata['WowzaStreamingEngine']['VHost'][i]['Name']:
              if args.verbose:
                print "found VHost",args.application
            
              if 'Name' in xmldata['WowzaStreamingEngine']['VHost'][i]['Application']:
                # Collect key stats here for vhost[name] and application
                if args.verbose:
                  print "Only 1 Application found:",xmldata['WowzaStreamingEngine']['VHost'][i]['Application']['Name']

                val = xmldata['WowzaStreamingEngine']['VHost'][i]['Application'][args.zkey]
                if args.zkey == "Status":
                  key = val
                else:
                  m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
                  if m:
                    key = float(m.group(0))*(10**float(m.group(1)))
                  else:
                    key = float(val)

              else:
                # collect key stats here for single vhost[name] and application[Name]
                for j in range(len(xmldata['WowzaStreamingEngine']['VHost'][i]['Application'])):
                  if args.verbose:
                    print "Application:",xmldata['WowzaStreamingEngine']['VHost'][i]['Application'][j]['Name']
                  if args.application == xmldata['WowzaStreamingEngine']['VHost'][i]['Application'][j]['Name']:
                    if args.verbose:
                      print "found App",args.application
                    val = xmldata['WowzaStreamingEngine']['VHost'][i]['Application'][j][args.zkey]
                    if args.zkey == "Status":
                      key = val
                    else:
                      m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
                      if m:
                        key = float(m.group(0))*(10**float(m.group(1)))
                      else:
                        key = float(val)

  elif args.vhost:
    if 'Name' in xmldata['WowzaStreamingEngine']['VHost']:
      # collect key stats here for single vhost
      if args.verbose:
        print "Only 1 Vhost found:",xmldata['WowzaStreamingEngine']['VHost']['Name']
      val = xmldata['WowzaStreamingEngine']['VHost'][args.zkey]
      m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
      if m:
        key = float(m.group(0))*(10**float(m.group(1)))
      else:
        key = float(val)
        
    else:
      # collect key stats here for vhost[name]
      for i in range(len(xmldata['WowzaStreamingEngine']['VHost'])):
        if args.verbose:
          print "Vhost:",xmldata['WowzaStreamingEngine']['VHost'][i]['Name']
        if args.vhost == xmldata['WowzaStreamingEngine']['VHost'][i]['Name']:
          if args.verbose:
            print "found VHost",args.application
          val = xmldata['WowzaStreamingEngine']['VHost'][args.zkey]
          if args.zkey == "Status":
            key = val
          else:
            m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
            if m:
              key = float(m.group(0))*(10**float(m.group(1)))
            else:
              key = float(val)

  else:
    if args.zkey in xmldata['WowzaStreamingEngine']:
        val = xmldata['WowzaStreamingEngine'][args.zkey]
        if args.zkey == "Status":
          key = val
        else:
          m = re.match(r"^(\d+)\s*E\s*(\d+)$",val)
          if m:
            key = float(m.group(0))*(10**float(m.group(1)))
          else:
            key = float(val)

  return key

if args.query:
  if (args.query == 'vhost') or (args.query == 'vhosts'):
    result = query_vhosts()
  else:
    result = query_all()
elif args.zkey:
  result = get_data()
else:
  print "Either query the server, or send in a key to fetch"

if result <> '':
  print str(result)
else:
  print "Did not find the specified key"
    
