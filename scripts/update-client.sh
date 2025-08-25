#!/bin/bash
# 带宽监控系统 - 客户端一键更新脚本
set -e
GITHUB_REPO="annabeautiful1/bandwidth-monitor"
SERVICE_NAME="bandwidth-monitor-client"
INSTALL_DIR="/opt/bandwidth-monitor-client"
BIN="${INSTALL_DIR}/client"

if [[ $EUID -ne 0 ]]; then echo "请用 sudo 运行"; exit 1; fi

LATEST=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
[[ -z "$LATEST" ]] && { echo "获取最新版本失败"; exit 1; }
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) FILE="bandwidth-monitor-client-linux-amd64" ;;
  aarch64) FILE="bandwidth-monitor-client-linux-arm64" ;;
  *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac
URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST}/${FILE}"

echo "下载: $URL"
mkdir -p "$INSTALL_DIR"
curl -L -o "$BIN" "$URL"
chmod +x "$BIN"

systemctl restart "$SERVICE_NAME"
systemctl status "$SERVICE_NAME" --no-pager || true

echo "✓ 更新完成 -> $LATEST"
