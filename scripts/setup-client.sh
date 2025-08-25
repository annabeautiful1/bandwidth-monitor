#!/bin/bash

# 一键非交互安装客户端
# 用法: sudo bash setup-client.sh <password> <server_url> <name> [iface] [interval]
# 例:   sudo bash setup-client.sh abc123 http://api.example.com:8080 CN-GZ-QZY-1G eth0 60

set -e

if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行本脚本" >&2
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "用法: $0 <password> <server_url> <name> [iface] [interval]" >&2
  exit 1
fi

PASSWORD="$1"
SERVER_URL="$2"
HOSTNAME="$3"
IFACE="${4:-}"
REPORT_INTERVAL="${5:-60}"

# 透传到标准安装脚本所需的环境变量
export PASSWORD
export SERVER_URL
export HOSTNAME
export REPORT_INTERVAL
if [ -n "$IFACE" ]; then
  export IFACE
fi

bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh)
