#!/bin/bash

# 带宽监控系统 - 客户端安装脚本
# 支持 Linux amd64/arm64 架构

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目信息
GITHUB_REPO="annabeautiful1/bandwidth-monitor"
SERVICE_NAME="bandwidth-monitor-client"
INSTALL_DIR="/opt/bandwidth-monitor-client"
CONFIG_FILE="$INSTALL_DIR/client.json"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  带宽监控系统 - 客户端安装程序   ${NC}"
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

# 下载URL
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/bandwidth-monitor-client-linux-$ARCH"

# 创建安装目录
echo -e "${YELLOW}创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"

# 下载二进制文件
echo -e "${YELLOW}正在下载客户端程序...${NC}"
if ! curl -L -o "$INSTALL_DIR/client" "$DOWNLOAD_URL"; then
    echo -e "${RED}下载失败，请检查网络连接或版本信息${NC}"
    exit 1
fi

# 设置执行权限
chmod +x "$INSTALL_DIR/client"

echo -e "${GREEN}客户端程序下载完成${NC}"

#############################################
# 配置收集（支持环境变量与 /dev/tty 交互）
#############################################
echo -e "${BLUE}开始配置收集...${NC}"

# 服务器地址（env: SERVER_URL）
if [ -n "${SERVER_URL:-}" ]; then
    server_url="$SERVER_URL"
else
    while true; do
        read -r -p "请输入服务器地址 (例: http://your-server.com:8080): " server_url </dev/tty || true
        if [[ "$server_url" =~ ^https?:// ]]; then
            break
        else
            echo -e "${RED}请输入完整的服务器地址，包含 http:// 或 https://${NC}"
        fi
    done
fi

# 访问密码（env: PASSWORD）
if [ -n "${PASSWORD:-}" ]; then
    password="$PASSWORD"
else
    while true; do
        read -r -s -p "请输入服务器访问密码: " password </dev/tty || true
        echo
        if [ -n "$password" ]; then
            break
        else
            echo -e "${RED}密码不能为空${NC}"
        fi
    done
fi

# 节点名称（env: HOSTNAME）
if [ -n "${HOSTNAME:-}" ]; then
    hostname="$HOSTNAME"
else
    default_hostname=$(hostname)
    read -r -p "请输入节点名称 (默认: $default_hostname): " hostname </dev/tty || true
    hostname=${hostname:-$default_hostname}
fi

# 上报间隔（env: REPORT_INTERVAL，默认 60，>=10）
if [ -n "${REPORT_INTERVAL:-}" ]; then
    report_interval="$REPORT_INTERVAL"
else
    while true; do
        read -r -p "请设置上报间隔 (秒，默认: 60): " report_interval </dev/tty || true
        report_interval=${report_interval:-60}
        if [[ "$report_interval" =~ ^[0-9]+$ ]] && [ "$report_interval" -ge 10 ]; then
            break
        else
            echo -e "${RED}请输入大于等于10的数字${NC}"
        fi
    done
fi

# 生成配置文件
echo -e "${YELLOW}正在生成配置文件...${NC}"
cat > "$CONFIG_FILE" << EOF
{
  "password": "$password",
  "server_url": "$server_url",
  "hostname": "$hostname",
  "report_interval_seconds": $report_interval
}
EOF

# 创建systemd服务
echo -e "${YELLOW}正在创建systemd服务...${NC}"
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Bandwidth Monitor Client
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/client -config=$CONFIG_FILE
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd并启动服务
echo -e "${YELLOW}正在启动服务...${NC}"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# 检查服务状态
sleep 3
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
    
    # 检查日志中的连接状态
    echo -e "${YELLOW}正在检查连接状态...${NC}"
    sleep 2
    
    if journalctl -u "$SERVICE_NAME" --no-pager -n 10 | grep -q "上报成功"; then
        echo -e "${GREEN}✓ 客户端已成功连接到服务器${NC}"
    elif journalctl -u "$SERVICE_NAME" --no-pager -n 10 | grep -q "密码错误"; then
        echo -e "${RED}✗ 密码错误，请检查配置${NC}"
        echo -e "${YELLOW}请修改配置文件: $CONFIG_FILE${NC}"
    elif journalctl -u "$SERVICE_NAME" --no-pager -n 10 | grep -q "连接失败\|请求失败"; then
        echo -e "${RED}✗ 无法连接到服务器，请检查服务器地址和网络${NC}"
    else
        echo -e "${YELLOW}连接状态未知，请查看日志获取详细信息${NC}"
    fi
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
echo -e "${YELLOW}客户端信息:${NC}"
echo "  - 安装目录: $INSTALL_DIR"
echo "  - 配置文件: $CONFIG_FILE"
echo "  - 服务器地址: $server_url"
echo "  - 节点名称: $hostname"
echo "  - 上报间隔: ${report_interval}秒"
echo "  - 服务名称: $SERVICE_NAME"
echo
echo -e "${YELLOW}常用命令:${NC}"
echo "  - 查看状态: systemctl status $SERVICE_NAME"
echo "  - 查看日志: journalctl -u $SERVICE_NAME -f"
echo "  - 重启服务: systemctl restart $SERVICE_NAME"
echo "  - 停止服务: systemctl stop $SERVICE_NAME"
echo
echo -e "${YELLOW}配置修改:${NC}"
echo "  - 编辑配置: nano $CONFIG_FILE"
echo "  - 重启生效: systemctl restart $SERVICE_NAME"
echo
echo -e "${GREEN}客户端已开始向服务器上报系统监控数据！${NC}"

# 显示最近的日志
echo
echo -e "${YELLOW}最近的运行日志:${NC}"
journalctl -u "$SERVICE_NAME" --no-pager -n 5