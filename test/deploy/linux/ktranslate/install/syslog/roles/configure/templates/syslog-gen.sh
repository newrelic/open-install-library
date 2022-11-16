#!/bin/bash

while [ true ]; do
  echo "test syslog message via ktranslate" >> /dev/udp/127.0.0.1/514
  sleep 5
done
