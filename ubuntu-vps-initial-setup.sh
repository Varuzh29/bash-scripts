#!/bin/bash

echo "update"
apt-get update
echo "upgrade"
apt-get upgrade -y
echo "install speedtest-cli"
apt-get install speedtest-cli -y
