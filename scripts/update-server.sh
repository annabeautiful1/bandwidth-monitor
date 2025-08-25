#!/bin/bash
# 带宽监控系统 - 服务端一键更新脚本
set -e
GITHUB_REPO="annabeautiful1/bandwidth-monitor"
SERVICE_NAME="bandwidth-monitor"
INSTALL_DIR="/opt/bandwidth-monitor"
BIN="${INSTALL_DIR}/server"

if [[ $EUID -ne 0 ]]; then echo "请用 sudo 运行"; exit 1; fi

LATEST=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
[[ -z "$LATEST" ]] && { echo "获取最新版本失败"; exit 1; }
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) FILE="bandwidth-monitor-server-linux-amd64" ;;
  aarch64) FILE="bandwidth-monitor-server-linux-arm64" ;;
  *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac
URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST}/${FILE}"

echo "停止服务: $SERVICE_NAME (若不存在将忽略)"
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

echo "下载: $URL"
mkdir -p "$INSTALL_DIR"
TMP_FILE=$(mktemp /tmp/server.XXXXXX)
curl -L --fail -o "$TMP_FILE" "$URL"
chmod +x "$TMP_FILE"

echo "替换二进制..."
mv -f "$TMP_FILE" "$BIN"

echo "启动服务: $SERVICE_NAME"
systemctl start "$SERVICE_NAME"
systemctl status "$SERVICE_NAME" --no-pager || true

echo "✓ 更新完成 -> $LATEST"
