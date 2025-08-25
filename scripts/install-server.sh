#!/bin/bash

# 带宽监控系统 - 服务端安装脚本
# 支持 Linux amd64/arm64 架构

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目信息
GITHUB_REPO="annabeautiful1/bandwidth-monitor"
SERVICE_NAME="bandwidth-monitor"
INSTALL_DIR="/opt/bandwidth-monitor"
CONFIG_FILE="$INSTALL_DIR/config.json"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  带宽监控系统 - 服务端安装程序   ${NC}"
echo -e "${BLUE}================================${NC}"
echo

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}" 
   exit 1
fi

# 检测系统架构
ARCH=""
case $(uname -m) in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}不支持的系统架构: $(uname -m)${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}检测到系统架构: $ARCH${NC}"

# 获取最新版本
echo -e "${YELLOW}正在获取最新版本信息...${NC}"
LATEST_VERSION=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}无法获取最新版本信息，请检查网络连接${NC}"
    exit 1
fi

echo -e "${GREEN}最新版本: $LATEST_VERSION${NC}"

# 下载URL（可通过 RELEASE_MIRROR 指定镜像前缀，例如 https://ghproxy.com/）
BASE_GH="https://github.com"
if [ -n "${RELEASE_MIRROR:-}" ]; then
    BASE_GH="$RELEASE_MIRROR"
fi
DOWNLOAD_URL="$BASE_GH/$GITHUB_REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-server-linux-$ARCH"

# 创建安装目录
echo -e "${YELLOW}创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"

# 下载二进制文件
echo -e "${YELLOW}正在下载服务端程序...${NC}"
if ! curl -L -o "$INSTALL_DIR/server" "$DOWNLOAD_URL"; then
    echo -e "${RED}下载失败，请检查网络连接或版本信息${NC}"
    exit 1
fi

# 设置执行权限
chmod +x "$INSTALL_DIR/server"

echo -e "${GREEN}服务端程序下载完成${NC}"

#############################################
# 配置收集（支持环境变量与 /dev/tty 交互）
#############################################
echo -e "${BLUE}开始配置收集...${NC}"

# 访问密码（env: PASSWORD）
if [ -n "${PASSWORD:-}" ]; then
    password="$PASSWORD"
else
    while true; do
        # 从 /dev/tty 读取，保证在 curl | bash 下可交互
        read -r -s -p "请设置访问密码: " password </dev/tty || true
        echo
        if [ -n "$password" ]; then
            break
        else
            echo -e "${RED}密码不能为空${NC}"
        fi
    done
fi

# 监听端口（env: LISTEN_PORT，默认 8080）
if [ -n "${LISTEN_PORT:-}" ]; then
    listen_port="$LISTEN_PORT"
else
    while true; do
        read -r -p "请设置监听端口 (默认: 8080): " listen_port </dev/tty || true
        listen_port=${listen_port:-8080}
        if [[ "$listen_port" =~ ^[0-9]+$ ]] && [ "$listen_port" -ge 1 ] && [ "$listen_port" -le 65535 ]; then
            break
        else
            echo -e "${RED}请输入有效的端口号 (1-65535)${NC}"
        fi
    done
fi

# 域名/IP（env: DOMAIN，默认 localhost）
if [ -n "${DOMAIN:-}" ]; then
    domain="$DOMAIN"
else
    read -r -p "请输入服务器域名或IP (用于客户端连接，默认: localhost): " domain </dev/tty || true
    domain=${domain:-"localhost"}
fi

# Telegram 配置（env: TG_TOKEN, TG_CHAT_ID，可选）
if [ -n "${TG_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
    tg_token="$TG_TOKEN"
    tg_chat_id="$TG_CHAT_ID"
else
    read -r -p "是否配置Telegram机器人通知? (y/n): " enable_telegram </dev/tty || true
    if [[ "$enable_telegram" =~ ^[Yy]$ ]]; then
        read -r -p "请输入Telegram机器人Token: " tg_token </dev/tty || true
        read -r -p "请输入Telegram Chat ID: " tg_chat_id </dev/tty || true
    else
        tg_token=""
        tg_chat_id=0
    fi
fi

# 带宽阈值（env: BANDWIDTH_THRESHOLD，默认 10）
if [ -n "${BANDWIDTH_THRESHOLD:-}" ]; then
    bandwidth_threshold="$BANDWIDTH_THRESHOLD"
else
    while true; do
        read -r -p "请设置带宽告警阈值 (Mbps，默认: 10): " bandwidth_threshold </dev/tty || true
        bandwidth_threshold=${bandwidth_threshold:-10}
        if [[ "$bandwidth_threshold" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            break
        else
            echo -e "${RED}请输入有效的数字${NC}"
        fi
    done
fi

# 离线阈值（env: OFFLINE_SECONDS，默认 300）
if [ -n "${OFFLINE_SECONDS:-}" ]; then
    offline_threshold="$OFFLINE_SECONDS"
else
    while true; do
        read -r -p "请设置离线告警阈值 (秒，默认: 300): " offline_threshold </dev/tty || true
        offline_threshold=${offline_threshold:-300}
        if [[ "$offline_threshold" =~ ^[0-9]+$ ]]; then
            break
        else
            echo -e "${RED}请输入有效的数字${NC}"
        fi
    done
fi

# 生成配置文件
echo -e "${YELLOW}正在生成配置文件...${NC}"
cat > "$CONFIG_FILE" << EOF
{
  "password": "$password",
  "listen": ":$listen_port",
  "domain": "$domain",
  "telegram": {
    "bot_token": "$tg_token",
    "chat_id": $tg_chat_id
  },
  "thresholds": {
    "bandwidth_mbps": $bandwidth_threshold,
    "offline_seconds": $offline_threshold
  }
}
EOF

# 创建systemd服务
echo -e "${YELLOW}正在创建systemd服务...${NC}"
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Bandwidth Monitor Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/server -config=$CONFIG_FILE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd并启动服务
echo -e "${YELLOW}正在启动服务...${NC}"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# 检查服务状态
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
else
    echo -e "${RED}✗ 服务启动失败，请检查日志: journalctl -u $SERVICE_NAME${NC}"
    exit 1
fi

# 显示安装结果
echo
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✓ 安装完成！${NC}"
echo -e "${BLUE}================================${NC}"
echo
echo -e "${YELLOW}服务信息:${NC}"
echo "  - 安装目录: $INSTALL_DIR"
echo "  - 配置文件: $CONFIG_FILE"
echo "  - 监听地址: http://$domain:$listen_port"
echo "  - 服务名称: $SERVICE_NAME"
echo
echo -e "${YELLOW}常用命令:${NC}"
echo "  - 查看状态: systemctl status $SERVICE_NAME"
echo "  - 查看日志: journalctl -u $SERVICE_NAME -f"
echo "  - 重启服务: systemctl restart $SERVICE_NAME"
echo "  - 停止服务: systemctl stop $SERVICE_NAME"
echo
echo -e "${YELLOW}客户端连接信息:${NC}"
echo "  - 服务器地址: http://$domain:$listen_port"
echo "  - 访问密码: $password"
echo
echo -e "${GREEN}请保存好访问密码，客户端连接时需要使用！${NC}"

# 测试Telegram机器人
if [[ -n "$tg_token" ]] && [[ "$tg_chat_id" != "0" ]]; then
    echo
    read -p "是否发送测试消息到Telegram? (y/n): " test_telegram
    if [[ "$test_telegram" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}正在发送测试消息...${NC}"
        # 这里需要等待服务完全启动
        sleep 3
        if curl -s -X POST "http://localhost:$listen_port/api/test-telegram" > /dev/null 2>&1; then
            echo -e "${GREEN}测试消息发送成功！请检查您的Telegram${NC}"
        else
            echo -e "${RED}测试消息发送失败，请检查Telegram配置${NC}"
        fi
    fi
fi