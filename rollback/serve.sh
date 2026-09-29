#!/bin/sh
# Tiny HTTP endpoint on :9000. Any request triggers heal.sh (the rollback).
# The AWX remediation playbook hits this (uri module) for automatic self-healing;
# you can also curl it by hand to roll prod back.
echo "rollback webhook listening on :9000"
while true; do
  printf 'HTTP/1.1 200 OK\r\nContent-Length: 3\r\nConnection: close\r\n\r\nOK\n' | nc -l -p 9000 >/dev/null 2>&1
  echo "--- request received $(date -u +%T) ---"
  sh /rollback/heal.sh
done
