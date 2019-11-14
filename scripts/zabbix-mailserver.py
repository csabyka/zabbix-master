#!/usr/bin/python3

import os
import sys
import json
import socket
import traceback

from enum import Enum

DEBUG = False


class Service(Enum):
    SMTP = 25
    SMTPS = 465
    SUBMISSION = 587
    IMAP = 143
    IMAPS = 993
    POP3 = 110
    POP3S = 995
    LMTP = 24
    DOVECOT_QUOTA = 12340
    MANAGESIEVE = 4190
    CLAMAV = 3310
    VAULT = 8500
    CONSUL = 8200
    RSPAMD_PROXY = 11332
    RSPAMD_NORMAL = 11333
    RSPAMD_CONTROLLER = 11334
    RSPAMD_FUZZY = 11335
    OLEFY = 11150
    UWSGI_QUARANTAINE = 9100
    UWSGI_ARC = 9200
    OPENDKIM = 8892


def dbg(*args, **kw):
    if DEBUG:
        print(*args, **kw)


def main(hosts):
    data = list()
    del hosts[0]

    for host in hosts:
        for service in Service:
            if ":" in host:
                sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
            else:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)

            try:
                result = sock.connect_ex((host, service.value))
            except socket.gaierror:
                dbg("Hostname could not be resolved")
                continue
            except socket.error:
                dbg("Couldn't connect to server {0}".format(host_ip))
                continue
            finally:
                sock.close()

            if result == 0:
                service_type = "tcp"

                if service == Service.SMTP:
                    service_type = "smtp"
                elif service == Service.SUBMISSION:
                    service_type = "smtp"
                elif service == Service.LMTP:
                    service_type = "smtp"
                elif service == Service.POP3:
                    service_type = "pop"
                elif service == Service.IMAP:
                    service_type = "imap"
                elif service == Service.RSPAMD_NORMAL:
                    service_type = "http"
                elif service == Service.VAULT:
                    service_type = "http"
                elif service == Service.CONSUL:
                    service_type = "http"

                data.append({
                    '{#HOST}': host,
                    '{#PORT}': service.value,
                    '{#NAME}': str(service),
                    '{#SERVICE}': service_type})
                dbg("Found service {0}".format(service))

    return data


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("zabbix-mailserver.py ip_addr [ip_addr ...]")
        sys.exit(1)

    try:
        services = {"data": main(sys.argv)}
        dbg(services)
    except Exception as error:
        traceback.print_exc()
        dbg("Uncaught exception: {0}".format(error))
        sys.exit(os.EX_SOFTWARE)

    print(json.dumps(services))

    sys.exit(os.EX_OK)

# vim: ts=4 sw=4 expandtab
